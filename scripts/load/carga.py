#!/usr/bin/env python3
"""Prueba de carga de la beta: muchas cuentas usando la app a la vez contra un proyecto de Supabase.

A diferencia de `supabase/stress/` (que habla directamente con Postgres), aquí todo pasa por la
misma puerta que la app: Auth, PostgREST (`/rest/v1/rpc/*`, esquema `api`) y Realtime
(WebSocket con canales privados `user:<id>` y `conversation:<id>`). Así se miden también los
límites del plan de Supabase: conexiones de Realtime, peticiones por segundo, tamaño del pool.

Qué hace:
1. Prepara N cuentas beta (API de administración, sin correos), inicia sesión con cada una y
   crea un grafo social inicial: seguimientos, un post por cuenta y algunas conversaciones.
2. Sube por escalones (p. ej. 50 → 200 → 500 → 1000 usuarios a la vez). Cada usuario virtual
   abre su WebSocket como la app y repite lo que hace una persona: leer el feed, mirar no
   leídos, buscar en el directorio, ver perfiles, recomendar, seguir, publicar y escribir
   mensajes, con pausas de unos segundos entre acciones.
3. Mide por escalón: peticiones/s, p50/p95/p99, errores por operación y código, conexiones de
   Realtime aceptadas o rechazadas y cuánto tarda en llegar el aviso de un mensaje nuevo.
4. Borra las cuentas creadas (salvo CONSERVAR=1) y escribe un informe en Markdown.

NO se lanza contra el proyecto de la beta: usa un proyecto aparte («carga»). Por seguridad hay
que confirmar el ref del proyecto en CARGA_CONFIRMAR.

Uso (nube):
  SUPABASE_ACCESS_TOKEN=… SUPABASE_PROJECT_REF=abcd CARGA_CONFIRMAR=abcd python3 scripts/load/carga.py
Uso (Supabase local, escalones pequeños):
  source scripts/lib/supabase-env.sh
  SUPABASE_URL=$API_URL SUPABASE_ANON_KEY=$ANON_KEY SUPABASE_SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY \
    CARGA_CONFIRMAR=local ESCALONES=10,25 SEGUNDOS_ESCALON=30 python3 scripts/load/carga.py
Limpiar restos de una ejecución interrumpida:
  … python3 scripts/load/carga.py --limpiar

Variables: ESCALONES (50,200,500,1000) · SEGUNDOS_ESCALON (120) · RAMPA (30 s por escalón) ·
PAUSA_MIN/PAUSA_MAX (3/8 s entre acciones) · REALTIME (1 = todos con WebSocket; 0.5 = la mitad) ·
MAX_P95_MS (800) · MAX_ERRORES (0.01) · CONSERVAR (0) · INFORME (carga-informe.md).
Requiere: pip install "aiohttp>=3.10,<4"
"""

from __future__ import annotations

import asyncio
import json
import os
import random
import resource
import secrets
import sys
import time
import uuid
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

import aiohttp

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "deploy"))
from supa import Project, opt  # noqa: E402

RUN = secrets.token_hex(3)
EMAIL_DOMAIN = "carga.invalid"
PREFIX = "carga-"
SEED_FOLLOWS = 8
TEXTOS = [
    "Buscando contactos en el sector agroalimentario en México.",
    "¿Alguien de la promoción que esté ahora en Singapur?",
    "Comparto la guía de exportación que preparamos el año pasado.",
    "Ofrezco mentoría a quien empiece en la red exterior.",
    "Gran encuentro de antiguos becarios ayer en Madrid.",
]


def env_float(name: str, default: float) -> float:
    return float(opt(name, str(default)))


ESCALONES = [int(x) for x in opt("ESCALONES", "50,200,500,1000").split(",") if x.strip()]
SEGUNDOS_ESCALON = env_float("SEGUNDOS_ESCALON", 120)
RAMPA = env_float("RAMPA", 30)
PAUSA_MIN, PAUSA_MAX = env_float("PAUSA_MIN", 3), env_float("PAUSA_MAX", 8)
REALTIME = env_float("REALTIME", 1.0)
MAX_P95_MS = env_float("MAX_P95_MS", 800)
MAX_ERRORES = env_float("MAX_ERRORES", 0.01)
INFORME = opt("INFORME", "carga-informe.md")


def uuid7() -> str:
    """UUID v7, como los genera la app (la API rechaza ids que no lo sean)."""
    ms = time.time_ns() // 1_000_000
    rand = int.from_bytes(os.urandom(10), "big")
    v = ((ms & ((1 << 48) - 1)) << 80) | (0x7 << 76) | (((rand >> 62) & 0xFFF) << 64) | (0b10 << 62) \
        | (rand & ((1 << 62) - 1))
    return str(uuid.UUID(int=v))


def pct(values: list[float], p: float) -> float:
    if not values:
        return 0.0
    s = sorted(values)
    k = min(len(s) - 1, max(0, round(p / 100 * (len(s) - 1))))
    return s[k]


# ---------------------------------------------------------------------------------------------
# Métricas
# ---------------------------------------------------------------------------------------------
@dataclass
class Stage:
    vus: int
    started: float = 0.0
    ended: float = 0.0
    lat: dict[str, list[float]] = field(default_factory=lambda: defaultdict(list))
    errors: dict[str, int] = field(default_factory=lambda: defaultdict(int))
    samples: dict[str, str] = field(default_factory=dict)
    ws_tried: int = 0
    ws_ok: int = 0
    ws_errors: dict[str, int] = field(default_factory=lambda: defaultdict(int))
    ws_drops: int = 0
    deliveries_expected: int = 0
    delivery_ms: list[float] = field(default_factory=list)

    @property
    def requests(self) -> int:
        return sum(len(v) for v in self.lat.values()) + sum(self.errors.values())

    @property
    def all_lat(self) -> list[float]:
        return [x for v in self.lat.values() for x in v]


class Metrics:
    def __init__(self):
        self.stages: list[Stage] = []

    @property
    def cur(self) -> Stage:
        return self.stages[-1]

    def ok(self, op: str, ms: float):
        self.cur.lat[op].append(ms)

    def err(self, op: str, code: str, detail: str):
        key = f"{op} · {code}"
        self.cur.errors[key] += 1
        self.cur.samples.setdefault(key, detail[:200])


M = Metrics()


class ApiError(Exception):
    def __init__(self, code: str, detail: str):
        super().__init__(f"{code}: {detail}")
        self.code, self.detail = code, detail


# ---------------------------------------------------------------------------------------------
# Cuentas
# ---------------------------------------------------------------------------------------------
@dataclass
class Account:
    n: int
    email: str
    password: str
    id: str = ""
    token: str = ""
    refresh: str = ""
    expires_at: float = 0.0
    online: bool = False
    post_ids: list[str] = field(default_factory=list)


class Target:
    def __init__(self, project: Project, session: aiohttp.ClientSession):
        keys = project.keys()
        self.url = project.url.rstrip("/")
        self.anon, self.service = keys["anon"], keys["service_role"]
        self.http = session
        self.ws_url = self.url.replace("https://", "wss://").replace("http://", "ws://") + \
            f"/realtime/v1/websocket?apikey={self.anon}&vsn=1.0.0"

    # --- Auth ---------------------------------------------------------------------------------
    async def _auth(self, method: str, path: str, body=None, admin=False, ok=(200, 201, 204)):
        h = {"apikey": self.anon, "Content-Type": "application/json"}
        if admin:
            h |= {"apikey": self.service, "Authorization": f"Bearer {self.service}"}
        for attempt in range(8):
            async with self.http.request(method, f"{self.url}/auth/v1{path}", json=body, headers=h) as r:
                text = await r.text()
                if r.status == 429 or (r.status >= 500 and attempt < 3):
                    await asyncio.sleep(min(60, 2 ** attempt) + random.random())
                    continue
                if r.status not in ok:
                    raise ApiError(f"HTTP {r.status}", text)
                return json.loads(text) if text.strip() else None
        raise ApiError("HTTP 429", f"{path}: límite de Auth tras varios reintentos")

    async def create(self, a: Account):
        user = await self._auth("POST", "/admin/users", admin=True, body={
            "email": a.email, "password": a.password, "email_confirm": True,
            "user_metadata": {"name": f"Carga {a.n}", "promocion": str(random.randint(30, 51))}})
        a.id = user["id"]

    async def login(self, a: Account):
        s = await self._auth("POST", "/token?grant_type=password", body={"email": a.email, "password": a.password})
        self._session(a, s)

    async def refresh_if_needed(self, a: Account):
        if time.time() < a.expires_at - 120:
            return
        s = await self._auth("POST", "/token?grant_type=refresh_token", body={"refresh_token": a.refresh})
        self._session(a, s)

    @staticmethod
    def _session(a: Account, s: dict):
        a.token, a.refresh = s["access_token"], s["refresh_token"]
        a.expires_at = time.time() + float(s.get("expires_in", 3600))

    async def admin_delete(self, user_id: str):
        await self._auth("DELETE", f"/admin/users/{user_id}", admin=True, ok=(200, 204, 404))

    async def admin_list(self, page: int) -> list[dict]:
        r = await self._auth("GET", f"/admin/users?page={page}&per_page=500", admin=True)
        return (r or {}).get("users", [])

    # --- API ------------------------------------------------------------------------------------
    async def rpc(self, a: Account, fn: str, body: dict | None = None, op: str | None = None, record=True):
        await self.refresh_if_needed(a)
        h = {"apikey": self.anon, "Authorization": f"Bearer {a.token}", "Content-Type": "application/json",
             "Content-Profile": "api", "Accept-Profile": "api"}
        op = op or fn
        t0 = time.perf_counter()
        try:
            async with self.http.post(f"{self.url}/rest/v1/rpc/{fn}", json=body or {}, headers=h) as r:
                text = await r.text()
                ms = (time.perf_counter() - t0) * 1000
                if r.status >= 400:
                    code = f"HTTP {r.status}"
                    try:
                        code += f" {json.loads(text).get('code', '')}".rstrip()
                    except (ValueError, AttributeError):
                        pass
                    raise ApiError(code, text)
                if record:
                    M.ok(op, ms)
                return json.loads(text) if text.strip() else None
        except ApiError as e:
            if record:
                M.err(op, e.code, e.detail)
            raise
        except (aiohttp.ClientError, asyncio.TimeoutError) as e:
            if record:
                M.err(op, type(e).__name__, str(e))
            raise ApiError(type(e).__name__, str(e)) from None


# ---------------------------------------------------------------------------------------------
# Realtime (protocolo Phoenix, igual que supabase_flutter)
# ---------------------------------------------------------------------------------------------
class Realtime:
    def __init__(self, target: Target, a: Account, pending: dict, arrivals: dict):
        self.t, self.a, self.pending, self.arrivals = target, a, pending, arrivals
        self.closing = False
        self.ws: aiohttp.ClientWebSocketResponse | None = None
        self.ref = 0
        self.joins: dict[str, asyncio.Future] = {}
        self.task: asyncio.Task | None = None
        self.hb: asyncio.Task | None = None

    def _next(self) -> str:
        self.ref += 1
        return str(self.ref)

    async def connect(self) -> bool:
        st = M.cur
        st.ws_tried += 1
        try:
            self.ws = await self.t.http.ws_connect(self.t.ws_url, heartbeat=None, timeout=aiohttp.ClientWSTimeout(ws_close=10))
        except (aiohttp.ClientError, asyncio.TimeoutError) as e:
            st.ws_errors[f"conexión: {type(e).__name__} {getattr(e, 'status', '')}".strip()] += 1
            return False
        self.task = asyncio.create_task(self._reader())
        self.hb = asyncio.create_task(self._heartbeat())
        ok = await self.join(f"user:{self.a.id}")
        if ok:
            st.ws_ok += 1
        return ok

    async def join(self, topic: str) -> bool:
        if not self.ws or self.ws.closed:
            return False
        ref = self._next()
        fut = asyncio.get_running_loop().create_future()
        self.joins[ref] = fut
        await self.ws.send_json({
            "topic": f"realtime:{topic}", "event": "phx_join", "ref": ref, "join_ref": ref,
            "payload": {"config": {"broadcast": {"ack": False, "self": False}, "presence": {"key": "", "enabled": False},
                                   "postgres_changes": [], "private": True},
                        "access_token": self.a.token}})
        try:
            status, reason = await asyncio.wait_for(fut, 15)
        except asyncio.TimeoutError:
            status, reason = "timeout", "sin respuesta en 15 s"
        if status != "ok":
            M.cur.ws_errors[f"join: {reason}"[:120]] += 1
            return False
        return True

    async def leave(self, topic: str):
        if self.ws and not self.ws.closed:
            await self.ws.send_json({"topic": f"realtime:{topic}", "event": "phx_leave", "payload": {}, "ref": self._next()})

    async def _heartbeat(self):
        while self.ws and not self.ws.closed:
            await asyncio.sleep(25)
            try:
                await self.ws.send_json({"topic": "phoenix", "event": "heartbeat", "payload": {}, "ref": self._next()})
            except (ConnectionError, RuntimeError):
                return

    async def _reader(self):
        assert self.ws is not None
        async for msg in self.ws:
            if msg.type != aiohttp.WSMsgType.TEXT:
                continue
            m = json.loads(msg.data)
            ev, payload = m.get("event"), m.get("payload") or {}
            if ev == "phx_reply" and m.get("ref") in self.joins:
                fut = self.joins.pop(m["ref"])
                if not fut.done():
                    resp = payload.get("response") or {}
                    fut.set_result((payload.get("status"), resp.get("reason") or json.dumps(resp)[:100]))
            elif ev == "broadcast" and payload.get("event") == "conversation.updated":
                conv = (payload.get("payload") or {}).get("conversation_id")
                key, now = (self.a.id, conv), time.perf_counter()
                sent = self.pending.pop(key, None)
                if sent is not None:
                    M.cur.delivery_ms.append((now - sent) * 1000)
                else:  # llegó antes de que el remitente recibiera la respuesta de send_message
                    self.arrivals[key] = now
            elif ev in ("phx_error", "system") and payload.get("status") == "error":
                M.cur.ws_errors[f"canal: {payload.get('message', ev)}"[:120]] += 1
        if not self.closing:
            M.cur.ws_drops += 1

    async def close(self):
        self.closing = True
        for t in (self.hb,):
            if t:
                t.cancel()
        if self.ws and not self.ws.closed:
            await self.ws.close()
        if self.task:
            try:
                await asyncio.wait_for(self.task, 5)
            except (asyncio.TimeoutError, asyncio.CancelledError, aiohttp.ClientError):
                pass


# ---------------------------------------------------------------------------------------------
# Usuario virtual
# ---------------------------------------------------------------------------------------------
ACCIONES = [  # (peso, nombre) ≈ lo que hace una persona con la app abierta
    (30, "feed"), (12, "no_leidos"), (8, "directorio"), (8, "perfil"), (9, "recomendar"),
    (4, "seguir"), (3, "publicar"), (10, "mensaje"), (8, "conversaciones"), (5, "notificaciones"),
    (3, "latido"),
]
PESOS = [w for w, _ in ACCIONES]
NOMBRES = [n for _, n in ACCIONES]


class VirtualUser:
    def __init__(self, t: Target, a: Account, everyone: list[Account], pending: dict, arrivals: dict,
                 stop: asyncio.Event):
        self.t, self.a, self.everyone, self.pending, self.arrivals, self.stop = t, a, everyone, pending, arrivals, stop
        self.feed_ids: list[str] = []
        self.feed_cursor: str | None = None
        self.convs: list[str] = []
        self.rt: Realtime | None = None

    async def run(self):
        if random.random() < REALTIME:
            self.rt = Realtime(self.t, self.a, self.pending, self.arrivals)
            self.a.online = await self.rt.connect()
        try:
            await self._safe(self._open_app)
            while not self.stop.is_set():
                await self._safe(getattr(self, "_" + random.choices(NOMBRES, PESOS)[0]))
                try:
                    await asyncio.wait_for(self.stop.wait(), random.uniform(PAUSA_MIN, PAUSA_MAX))
                except asyncio.TimeoutError:
                    pass
        finally:
            self.a.online = False
            if self.rt:
                await self.rt.close()

    async def _safe(self, fn):
        try:
            await fn()
        except ApiError:
            pass  # ya contado en las métricas

    def _peer(self) -> Account:
        while True:
            b = random.choice(self.everyone)
            if b is not self.a:
                return b

    async def _open_app(self):  # lo que dispara la app al abrirse
        await self.t.rpc(self.a, "me")
        await asyncio.gather(self._feed(first=True), self._no_leidos())

    async def _feed(self, first=False):
        cursor = None if first or random.random() < 0.6 or not self.feed_cursor else self.feed_cursor
        page = await self.t.rpc(self.a, "get_feed", {"p_cursor": cursor, "p_limit": 20},
                                op="get_feed" if cursor is None else "get_feed (página 2+)")
        items = (page or {}).get("items") or []
        self.feed_ids = [i["id"] for i in items if i.get("id")] or self.feed_ids
        self.feed_cursor = (page or {}).get("next_cursor")

    async def _no_leidos(self):
        await self.t.rpc(self.a, "unread_counts")

    async def _directorio(self):
        await self.t.rpc(self.a, "search_directory", {"p_query": random.choice(["carga", "a", "ma", None])})

    async def _perfil(self):
        await self.t.rpc(self.a, "get_profile", {"p_user": self._peer().id})

    async def _recomendar(self):
        if not self.feed_ids:
            return await self._feed()
        await self.t.rpc(self.a, "recommend", {"p_post": random.choice(self.feed_ids)})

    async def _seguir(self):
        b = self._peer()
        await self.t.rpc(self.a, "follow" if random.random() < 0.7 else "unfollow", {"p_user": b.id})

    async def _publicar(self):
        await self.t.rpc(self.a, "create_post", {"p_id": uuid7(), "p_texto": f"{random.choice(TEXTOS)} [{RUN}]"})

    async def _mensaje(self):
        b = next((x for x in random.sample(self.everyone, min(5, len(self.everyone))) if x.online and x is not self.a),
                 None) or self._peer()
        sent = time.perf_counter()
        watch = b.online
        msg = await self.t.rpc(self.a, "send_message", {
            "p_id": uuid7(), "p_cuerpo": "Hola, ¿hablamos esta semana?", "p_to": b.id, "p_categoria": "networking"})
        conv = (msg or {}).get("conversation_id")
        if conv and watch:
            M.cur.deliveries_expected += 1
            arrived = self.arrivals.pop((b.id, conv), None)
            if arrived is not None and arrived >= sent:
                M.cur.delivery_ms.append((arrived - sent) * 1000)
            else:
                self.pending[(b.id, conv)] = sent
        if conv:
            self.convs.append(conv)
            await self._chat(conv)

    async def _chat(self, conv: str):
        if self.rt and random.random() < 0.5:  # abrir el chat: canal de la conversación
            await self.rt.join(f"conversation:{conv}")
        page = await self.t.rpc(self.a, "get_messages", {"p_conversation": conv})
        items = (page or {}).get("items") or []
        if items:
            await self.t.rpc(self.a, "mark_read", {"p_conversation": conv, "p_message_id": items[0]["id"]})
        if self.rt:
            await self.rt.leave(f"conversation:{conv}")

    async def _conversaciones(self):
        page = await self.t.rpc(self.a, "list_conversations", {})
        items = (page or {}).get("items") or []
        if items and random.random() < 0.5:
            await self._chat(random.choice(items)["id"])

    async def _notificaciones(self):
        await self.t.rpc(self.a, "list_notifications", {})
        if random.random() < 0.3:
            await self.t.rpc(self.a, "mark_notifications_read", {})

    async def _latido(self):
        await self.t.rpc(self.a, "heartbeat")


# ---------------------------------------------------------------------------------------------
# Fases
# ---------------------------------------------------------------------------------------------
async def bounded(n: int, items, fn, label: str):
    sem = asyncio.Semaphore(n)
    done, failed, first_err = 0, 0, ""

    async def one(x):
        nonlocal done, failed, first_err
        async with sem:
            try:
                await fn(x)
            except Exception as e:  # noqa: BLE001  (se informa y se sigue)
                failed += 1
                first_err = first_err or str(e)[:200]
            done += 1
            if done % 100 == 0:
                print(f"    {label}: {done}/{len(items)}", flush=True)

    await asyncio.gather(*(one(x) for x in items))
    if failed:
        print(f"    ⚠ {label}: {failed} fallos (primero: {first_err})")
    return failed


async def prepare(t: Target, n: int) -> list[Account]:
    print(f"→ Preparando {n} cuentas (etiqueta {RUN})")
    t0 = time.time()
    accs = [Account(i, f"{PREFIX}{RUN}-{i}@{EMAIL_DOMAIN}", secrets.token_urlsafe(18)) for i in range(n)]
    M.stages.append(Stage(0))  # las métricas de la preparación no cuentan
    await bounded(12, accs, t.create, "cuentas")
    accs = [a for a in accs if a.id]
    await bounded(12, accs, t.login, "inicios de sesión")
    accs = [a for a in accs if a.token]
    if len(accs) < n * 0.95:
        raise SystemExit(f"✗ Solo se prepararon {len(accs)}/{n} cuentas. Revisa los límites de Auth (abajo).")

    async def seed(a: Account):
        for b in random.sample(accs, min(SEED_FOLLOWS, len(accs) - 1)):
            if b is not a:
                await t.rpc(a, "follow", {"p_user": b.id}, record=False)
        await t.rpc(a, "create_post", {"p_id": uuid7(), "p_texto": f"{random.choice(TEXTOS)} [{RUN}]"}, record=False)
        if random.random() < 0.3:
            b = random.choice(accs)
            if b is not a:
                await t.rpc(a, "send_message", {"p_id": uuid7(), "p_cuerpo": "¡Hola!", "p_to": b.id,
                                                "p_categoria": "networking"}, record=False)

    await bounded(24, accs, seed, "grafo social")
    M.stages.clear()
    print(f"  ✓ {len(accs)} cuentas listas en {time.time() - t0:.0f} s")
    return accs


async def run_stages(t: Target, accs: list[Account]):
    stop = asyncio.Event()
    pending: dict = {}   # (destinatario, conversación) → cuándo se envió
    arrivals: dict = {}  # avisos que llegaron antes que la respuesta de send_message
    tasks: list[asyncio.Task] = []
    random.shuffle(accs)
    for vus in ESCALONES:
        vus = min(vus, len(accs))
        st = Stage(vus)
        M.stages.append(st)
        st.started = time.time()
        new = accs[len(tasks):vus]
        print(f"→ Escalón {vus} usuarios a la vez (+{len(new)} en {RAMPA:.0f} s, luego {SEGUNDOS_ESCALON:.0f} s)",
              flush=True)
        for a in new:
            tasks.append(asyncio.create_task(VirtualUser(t, a, accs, pending, arrivals, stop).run()))
            if RAMPA and new:
                await asyncio.sleep(RAMPA / len(new))
        await asyncio.sleep(SEGUNDOS_ESCALON)
        cutoff = time.perf_counter() - 30
        for d in (pending, arrivals):  # lo que no llegó en 30 s ya no va a llegar
            for k in [k for k, v in d.items() if v < cutoff]:
                del d[k]
        st.ended = time.time()
        summary(st, live=True)
    stop.set()
    await asyncio.gather(*tasks, return_exceptions=True)


async def cleanup(t: Target, accs: list[Account]):
    print(f"→ Borrando {len(accs)} cuentas de prueba")
    M.stages.append(Stage(0))

    async def drop(a: Account):
        try:  # el camino real de la app (borra también sus mensajes)
            await t.rpc(a, "delete_my_account", {"p_confirmacion": "BORRAR MI CUENTA"}, record=False)
        except ApiError:
            await t.admin_delete(a.id)

    await bounded(12, accs, drop, "borrado")


async def cleanup_leftovers(t: Target):
    """Borra cuentas de ejecuciones anteriores interrumpidas (emails @carga.invalid)."""
    ids, page = [], 1
    while True:
        users = await t.admin_list(page)
        ids += [u["id"] for u in users if (u.get("email") or "").endswith(f"@{EMAIL_DOMAIN}")]
        if len(users) < 500:
            break
        page += 1
    print(f"→ {len(ids)} cuentas de pruebas anteriores")
    await bounded(12, ids, t.admin_delete, "borrado")


# ---------------------------------------------------------------------------------------------
# Informe
# ---------------------------------------------------------------------------------------------
def verdict(st: Stage) -> tuple[bool, str]:
    reqs = st.requests or 1
    err_rate = sum(st.errors.values()) / reqs
    p95 = pct(st.all_lat, 95)
    ws_fail = st.ws_tried - st.ws_ok
    problems = []
    if err_rate > MAX_ERRORES:
        problems.append(f"errores {err_rate:.1%}")
    if p95 > MAX_P95_MS:
        problems.append(f"p95 {p95:.0f} ms")
    if ws_fail:
        problems.append(f"{ws_fail} sin tiempo real")
    return (not problems, "✓" if not problems else "✗ " + ", ".join(problems))


def summary(st: Stage, live=False) -> str:
    dur = max(1.0, (st.ended or time.time()) - st.started)
    lat = st.all_lat
    reqs = st.requests
    errs = sum(st.errors.values())
    deliv = len(st.delivery_ms)
    upto = M.stages[: M.stages.index(st) + 1] if st in M.stages else [st]
    ws_ok = sum(x.ws_ok - x.ws_drops for x in upto)
    ws_tried = sum(x.ws_tried for x in upto)
    line = (f"| {st.vus} | {reqs / dur:.1f} | {pct(lat, 50):.0f} | {pct(lat, 95):.0f} | {pct(lat, 99):.0f} | "
            f"{errs / (reqs or 1):.2%} | {ws_ok}/{ws_tried} | "
            f"{(deliv / st.deliveries_expected if st.deliveries_expected else 1):.0%} · {pct(st.delivery_ms, 95):.0f} ms | "
            f"{verdict(st)[1]} |")
    if live:
        print("  " + line, flush=True)
    return line


def report(target_url: str, n_accounts: int) -> str:
    out = [f"# Prueba de carga · {time.strftime('%Y-%m-%d %H:%M')}", "",
           f"Proyecto: `{target_url}` · {n_accounts} cuentas · escalones {ESCALONES} · "
           f"{SEGUNDOS_ESCALON:.0f} s por escalón · pausa entre acciones {PAUSA_MIN:.0f}–{PAUSA_MAX:.0f} s · "
           f"WebSocket en el {REALTIME:.0%} de los usuarios.", "",
           f"Criterio de «aguanta»: errores ≤ {MAX_ERRORES:.0%}, p95 ≤ {MAX_P95_MS:.0f} ms y todos con tiempo real.", "",
           "| Usuarios a la vez | Peticiones/s | p50 ms | p95 ms | p99 ms | Errores | Con tiempo real | Aviso de mensaje (llegan · p95) | Resultado |",
           "|---|---|---|---|---|---|---|---|---|"]
    out += [summary(st) for st in M.stages]
    ok_stages = [st.vus for st in M.stages if verdict(st)[0]]
    out += ["", f"**Aguanta hasta: {max(ok_stages) if ok_stages else 0} usuarios a la vez** "
            "(último escalón que cumple el criterio).", ""]
    for st in M.stages:
        out += [f"## {st.vus} usuarios: detalle por operación", "", "| Operación | n | p50 | p95 | p99 |", "|---|---|---|---|---|"]
        for op, v in sorted(st.lat.items(), key=lambda kv: -pct(kv[1], 95)):
            out.append(f"| {op} | {len(v)} | {pct(v, 50):.0f} | {pct(v, 95):.0f} | {pct(v, 99):.0f} |")
        if st.errors:
            out += ["", "| Error | Veces | Ejemplo |", "|---|---|---|"]
            for k, c in sorted(st.errors.items(), key=lambda kv: -kv[1]):
                out.append(f"| {k} | {c} | `{st.samples.get(k, '').replace('|', '/')[:120]}` |")
        if st.ws_errors or st.ws_drops:
            out += ["", "Tiempo real: " + ", ".join(f"{k} ×{c}" for k, c in st.ws_errors.items())
                    + (f"; {st.ws_drops} conexiones cortadas por el servidor" if st.ws_drops else "")]
        out.append("")
    out += ["Cómo leerlo: si falla el **tiempo real** antes que la API, el límite es de conexiones simultáneas de "
            "Realtime (200 en el plan gratuito de Supabase, 500 en Pro). Si sube el **p95** con errores `HTTP 5xx` o "
            "`timeout`, el límite es de CPU o del pool de conexiones de la base de datos (tamaño de instancia).", ""]
    return "\n".join(out)


# ---------------------------------------------------------------------------------------------
async def raise_auth_limits(p: Project):
    """En el proyecto de carga, sube los límites por IP de Auth: todas las cuentas entran desde una máquina."""
    if not p.token:
        print("  · local: límites de Auth de config.toml (usa escalones pequeños)")
        return
    try:
        p.mgmt("PATCH", "/config/auth", {"rate_limit_otp": 5000, "rate_limit_token_refresh": 5000,
                                          "rate_limit_verify": 5000})
        print("  ✓ límites de Auth por IP subidos en el proyecto de carga")
    except (RuntimeError, SystemExit) as e:
        print(f"  ⚠ no se pudieron subir los límites de Auth ({str(e)[:150]}); se reintentará con espera")


async def main() -> int:
    p = Project()
    confirm = opt("CARGA_CONFIRMAR")
    if confirm != p.ref:
        sys.exit(f"✗ Esto crea cientos de cuentas y mucho tráfico. Lánzalo contra un proyecto de pruebas y confírmalo "
                 f"con CARGA_CONFIRMAR={p.ref}.")
    soft, hard = resource.getrlimit(resource.RLIMIT_NOFILE)
    resource.setrlimit(resource.RLIMIT_NOFILE, (hard, hard))
    if soft < 4 * max(ESCALONES) and hard < 4 * max(ESCALONES):
        print(f"  ⚠ límite de ficheros abiertos {hard}: puede quedarse corto para {max(ESCALONES)} usuarios")
    planned = len(ESCALONES) * (SEGUNDOS_ESCALON + RAMPA) / 60
    print(f"→ Prueba de carga en {p.url}: escalones {ESCALONES}, ≈{planned:.0f} min")
    if planned > 50:
        print("  ⚠ más de 50 min: las sesiones caducan a la hora y habrá muchas renovaciones de token")

    timeout = aiohttp.ClientTimeout(total=30)
    async with aiohttp.ClientSession(timeout=timeout, connector=aiohttp.TCPConnector(limit=0, ttl_dns_cache=300)) as s:
        t = Target(p, s)
        if "--limpiar" in sys.argv:
            await cleanup_leftovers(t)
            return 0
        await raise_auth_limits(p)
        accs = await prepare(t, max(ESCALONES))
        try:
            await run_stages(t, accs)
        finally:
            if opt("CONSERVAR") == "1":
                print("  · CONSERVAR=1: las cuentas siguen ahí (bórralas con --limpiar)")
            else:
                await cleanup(t, accs)
                M.stages.pop()
    text = report(p.url, len(accs))
    Path(INFORME).write_text(text, encoding="utf-8")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as f:
            f.write(text + "\n")
    print("\n" + text)
    first_ok = bool(M.stages) and verdict(M.stages[0])[0]
    if not first_ok:
        print("✗ Ni siquiera el primer escalón cumple el criterio: hay un problema antes de hablar de escala.")
    return 0 if first_ok else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
