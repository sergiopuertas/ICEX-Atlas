#!/usr/bin/env python3
"""Pruebas de concurrencia y paralelismo contra la base de datos local real.

Cada escenario lanza muchas conexiones a la vez (como muchos móviles llamando a PostgREST)
y después comprueba invariantes: nada duplicado, contadores exactos, aforos respetados,
colas sin doble entrega y ningún interbloqueo ni error inesperado.

Uso:  python3 supabase/stress/concurrency.py [nombre_escenario ...]
Requiere `supabase start` (o DB_URL apuntando a una base con las migraciones aplicadas).
"""

from __future__ import annotations

import sys
import threading
import time
from datetime import datetime, timedelta, timezone

from harness import (RUN, Client, Outcome, cleanup, create_members, q, q1, rnd,
                     run_parallel, uuid7)

FAILURES: list[str] = []
SCENARIOS = {}


def scenario(fn):
    SCENARIOS[fn.__name__] = fn
    return fn


def check(cond: bool, msg: str):
    if not cond:
        FAILURES.append(msg)
        print(f"    ✗ {msg}")
    else:
        print(f"    ✓ {msg}")


def no_unexpected(o: Outcome, allowed: set[str] = frozenset(), label: str = ""):
    bad = o.unexpected(allowed)
    detail = "; ".join(f"{k}×{v}: {o.samples[k]}" for k, v in bad.items())
    check(not bad, f"{label}sin errores inesperados {detail}".strip())


def clients(ids, n_each=1):
    return [Client(i) for i in ids for _ in range(n_each)]


def close(cs):
    for c in cs:
        c.close()


# ------------------------------------------------------------------ mensajería ------

@scenario
def send_message_idempotent_under_retries():
    """El móvil reintenta el mismo envío desde varias conexiones a la vez."""
    a, b, c = create_members(3, "idem")
    ca = Client(a)
    conv = ca.call("send_message", p_id=uuid7(), p_cuerpo="hola", p_to=b)["conversation_id"]
    ca.close()

    msg_id = uuid7()
    cs = clients([a], 24)
    results = []
    o = run_parallel([lambda cl=cl: results.append(cl.call("send_message", p_id=msg_id, p_cuerpo="reintento",
                                                           p_conversation_id=conv)) for cl in cs], 24)
    no_unexpected(o)
    check(q1("select count(*) from messaging.messages where id = %s", msg_id) == 1, "un único mensaje persistido")
    check(sum(1 for r in results if not r["duplicado"]) == 1, "exactamente una respuesta 'nuevo', el resto 'duplicado'")
    check(q1("select no_leidos from messaging.conversation_members where conversation_id=%s and user_id=%s",
             conv, b) == 2, "el destinatario cuenta 2 no leídos (no 25)")

    # Primer contacto (crea la conversación) con 24 reintentos simultáneos.
    first = uuid7()
    o = run_parallel([lambda cl=cl: cl.call("send_message", p_id=first, p_cuerpo="primer contacto", p_to=c)
                      for cl in cs], 24)
    no_unexpected(o, label="primer contacto: ")
    check(q1("select count(*) from messaging.conversations where direct_key = messaging.direct_key(%s, %s)", a, c) == 1,
          "una sola conversación directa")
    check(q1("select count(*) from messaging.messages where id = %s", first) == 1, "un solo mensaje")
    close(cs)


@scenario
def crossed_first_contact():
    """Dos socios se escriben por primera vez exactamente a la vez (40 parejas)."""
    ids = create_members(80, "cross")
    pairs = [(ids[i], ids[i + 40]) for i in range(40)]
    cs = {i: Client(i) for i in ids}
    tasks = []
    for a, b in pairs:
        tasks.append(lambda a=a, b=b: cs[a].call("send_message", p_id=uuid7(), p_cuerpo="hola", p_to=b))
        tasks.append(lambda a=a, b=b: cs[b].call("send_message", p_id=uuid7(), p_cuerpo="hola", p_to=a))
    o = run_parallel(tasks, 80)
    no_unexpected(o)
    bad = q("""select count(*) from (
                 select c.id, (select count(*) from messaging.conversation_members m where m.conversation_id=c.id) nm,
                        (select count(*) from messaging.messages x where x.conversation_id=c.id) nmsg
                   from messaging.conversations c
                  where c.direct_key = any(%s)) t where nm <> 2 or nmsg <> 2""",
            [f"{min(a, b)}:{max(a, b)}" for a, b in pairs])[0][0]
    n_conv = q1("select count(*) from messaging.conversations where direct_key = any(%s)",
                [f"{min(a, b)}:{max(a, b)}" for a, b in pairs])
    check(n_conv == 40, f"40 conversaciones, una por pareja (hay {n_conv})")
    check(bad == 0, "cada conversación con 2 participantes y los 2 mensajes")
    close(cs.values())


UNREAD_INVARIANT = """
  select count(*) from messaging.conversation_members cm
   where cm.conversation_id = %s
     and cm.no_leidos < (select count(*) from messaging.messages m
                           where m.conversation_id = cm.conversation_id and m.remitente_id <> cm.user_id
                             and (cm.ultimo_leido_id is null or m.id > cm.ultimo_leido_id))"""


@scenario
def chat_storm_unread_consistency():
    """400 mensajes cruzados + marcas de leído concurrentes: contadores y último mensaje exactos."""
    a, b = create_members(2, "storm")
    ca = Client(a)
    conv = ca.call("send_message", p_id=uuid7(), p_cuerpo="inicio", p_to=b)["conversation_id"]
    ca.close()
    senders = clients([a], 8) + clients([b], 8)
    readers = clients([a], 2) + clients([b], 2)
    stop = threading.Event()

    def send_many(cl):
        for k in range(25):
            cl.call("send_message", p_id=uuid7(), p_cuerpo=f"m{k}", p_conversation_id=conv)

    def read_loop(cl):
        while not stop.is_set():
            last = q1("select id from messaging.messages where conversation_id=%s order by id desc limit 1", conv)
            cl.call("mark_read", p_conversation=conv, p_message_id=last)
            time.sleep(0.005)

    rthreads = [threading.Thread(target=read_loop, args=(r,)) for r in readers]
    for t in rthreads:
        t.start()
    o = run_parallel([lambda cl=cl: send_many(cl) for cl in senders], 16)
    stop.set()
    for t in rthreads:
        t.join()
    no_unexpected(o)
    check(q1("select count(*) from messaging.messages where conversation_id=%s", conv) == 401, "401 mensajes")
    check(q1("""select c.ultimo_mensaje_id = (select id from messaging.messages where conversation_id = c.id order by id desc limit 1)
                from messaging.conversations c where id=%s""", conv), "ultimo_mensaje_id es el más reciente")
    check(q1(UNREAD_INVARIANT, conv) == 0, "no_leidos nunca por debajo de lo pendiente de leer")
    # Tras leer todo, ambos a cero.
    last = q1("select id from messaging.messages where conversation_id=%s order by id desc limit 1", conv)
    for u in (a, b):
        cl = Client(u)
        cl.call("mark_read", p_conversation=conv, p_message_id=last)
        cl.close()
    check(q1("select sum(no_leidos) from messaging.conversation_members where conversation_id=%s", conv) == 0,
          "tras leer el último, ambos a 0")
    close(senders + readers)


@scenario
def out_of_order_message_ids():
    """Un mensaje escrito sin conexión llega después de otros más nuevos (id más antiguo)."""
    a, b = create_members(2, "ooo")
    ca, cb = Client(a), Client(b)
    old_id = uuid7()          # A lo escribe sin cobertura…
    time.sleep(0.01)
    conv = cb.call("send_message", p_id=uuid7(), p_cuerpo="¿estás?", p_to=a)["conversation_id"]
    time.sleep(0.01)
    newest = uuid7()
    cb.call("send_message", p_id=newest, p_cuerpo="te escribo luego", p_conversation_id=conv)
    ca.call("mark_read", p_conversation=conv, p_message_id=newest)
    ca.call("send_message", p_id=old_id, p_cuerpo="(enviado al recuperar cobertura)", p_conversation_id=conv)
    last = q1("select ultimo_mensaje_id from messaging.conversations where id=%s", conv)
    check(str(last) == str(newest), "el último mensaje de la conversación no retrocede")
    pointer = q1("select ultimo_leido_id from messaging.conversation_members where conversation_id=%s and user_id=%s",
                 conv, a)
    check(str(pointer) == str(newest), "el puntero de leído del remitente no retrocede")
    check(q1(UNREAD_INVARIANT, conv) == 0, "no_leidos coherente")
    ca.close()
    cb.close()


@scenario
def message_id_validation():
    """Ids que romperían el orden: aleatorios (v4) o con fecha futura."""
    import uuid as _uuid
    a, b = create_members(2, "idv")
    ca = Client(a)
    for label, bad in (("v4 aleatorio", _uuid.uuid4()), ("v7 del futuro", _future_uuid7(days=2)),
                       ("máximo", _uuid.UUID("ffffffff-ffff-7fff-bfff-ffffffffffff"))):
        try:
            ca.call("send_message", p_id=bad, p_cuerpo="x", p_to=b)
            check(False, f"rechaza id {label}")
        except Exception as e:  # noqa: BLE001
            check(getattr(e, "sqlstate", "") == "22023", f"rechaza id {label} con 22023")
    ca.call("send_message", p_id=_future_uuid7(seconds=30), p_cuerpo="reloj algo adelantado", p_to=b)
    check(True, "acepta un reloj del móvil ligeramente adelantado")
    ca.close()


def _future_uuid7(days=0, seconds=0):
    base = uuid7().int
    ms = ((base >> 80) + int((days * 86400 + seconds) * 1000)) & ((1 << 48) - 1)
    import uuid as _uuid
    return _uuid.UUID(int=(base & ((1 << 80) - 1)) | (ms << 80))


@scenario
def notification_grouping_race():
    """25 recomendaciones simultáneas por post, 20 posts: una notificación agrupada por post."""
    ids = create_members(26, "ngr")
    author, fans = ids[0], ids[1:]
    au = Client(author)
    posts = [uuid7() for _ in range(20)]
    for p in posts:
        au.call("create_post", p_id=p, p_texto="agrupación")
    au.close()
    cs = clients(fans, 1)
    total = Outcome()
    for p in posts:
        run_parallel([lambda cl=cl, p=p: cl.call("recommend", p_post=p) for cl in cs], 25, total)
    no_unexpected(total)
    rows = q("""select group_key, count(*), max(total) from notifications.notifications
                where user_id=%s and not leido group by 1""", author)
    check(len(rows) == 20 and all(r[1] == 1 for r in rows), "una notificación sin leer por post")
    check(all(r[2] == 25 for r in rows), f"el total agrupado cuenta las 25 recomendaciones ({sorted({r[2] for r in rows})})")
    close(cs)


@scenario
def block_versus_send():
    """Un bloqueo concurrente con envíos: tras el bloqueo no entra ningún mensaje nuevo."""
    a, b = create_members(2, "blk")
    ca = Client(a)
    conv = ca.call("send_message", p_id=uuid7(), p_cuerpo="hola", p_to=b)["conversation_id"]
    ca.close()
    cs = clients([b], 12)
    blocker = Client(a)
    blocked_at = {}

    def spam(cl):
        for _ in range(20):
            try:
                cl.call("send_message", p_id=uuid7(), p_cuerpo="spam", p_conversation_id=conv)
            except Exception as e:  # noqa: BLE001
                if getattr(e, "sqlstate", "") != "42501":
                    raise

    def block():
        time.sleep(0.05)
        blocker.call("block", p_user=b)
        blocked_at["id"] = str(uuid7())

    o = run_parallel([lambda cl=cl: spam(cl) for cl in cs] + [block], 13)
    no_unexpected(o)
    late = q1("select count(*) from messaging.messages where conversation_id=%s and remitente_id=%s and id > %s",
              conv, b, blocked_at["id"])
    check(late == 0, f"ningún mensaje aceptado después del bloqueo ({late})")
    close(cs + [blocker])


# ------------------------------------------------------------- contadores sociales -----

@scenario
def recommend_storm():
    """60 socios recomiendan y retiran a la vez el mismo post."""
    ids = create_members(61, "reco")
    author, fans = ids[0], ids[1:]
    post = uuid7()
    ca = Client(author)
    ca.call("create_post", p_id=post, p_texto="Post para estrés")
    ca.close()
    cs = clients(fans, 1)

    def toggle(cl):
        for _ in range(12):
            if rnd.random() < 0.6:
                cl.call("recommend", p_post=post)
            else:
                cl.call("unrecommend", p_post=post)

    o = run_parallel([lambda cl=cl: toggle(cl) for cl in cs], 60)
    no_unexpected(o)
    stored, real = q("""select p.recomendaciones_count, (select count(*) from feed.recommendations r where r.post_id = p.id)
                          from feed.posts p where p.id = %s""", post)[0]
    check(stored == real, f"recomendaciones_count exacto ({stored} = {real})")
    n = q1("select count(*) from notifications.notifications where user_id=%s and group_key=%s and not leido",
           author, f"reco:{post}")
    check(n <= 1, f"una sola notificación agrupada sin leer ({n})")
    close(cs)


@scenario
def follow_storm():
    ids = create_members(51, "fol")
    star, fans = ids[0], ids[1:]
    cs = clients(fans, 1)

    def toggle(cl):
        for _ in range(10):
            (cl.call("follow", p_user=star) if rnd.random() < 0.6 else cl.call("unfollow", p_user=star))
        # Y siguen entre ellos para cruzar contadores
        other = rnd.choice(fans)
        if other != cl.user_id:
            cl.call("follow", p_user=other)

    o = run_parallel([lambda cl=cl: toggle(cl) for cl in cs], 50)
    no_unexpected(o)
    bad = q1("""select count(*) from profiles.profiles p where p.user_id = any(%s) and (
                 p.seguidores_count <> (select count(*) from social.follows f where f.seguido_id = p.user_id) or
                 p.siguiendo_count <> (select count(*) from social.follows f where f.seguidor_id = p.user_id))""", ids)
    check(bad == 0, "seguidores_count y siguiendo_count exactos para todos")
    n = q1("select count(*) from notifications.notifications where user_id=%s and not leido and group_key is not null "
           "group by group_key order by 1 desc limit 1", star) or 0
    check(n <= 1, "notificaciones de seguidores agrupadas sin duplicados")
    close(cs)


@scenario
def comment_storm():
    ids = create_members(41, "com")
    author, others = ids[0], ids[1:]
    post = uuid7()
    ca = Client(author)
    ca.call("create_post", p_id=post, p_texto="Post con muchos comentarios")
    ca.close()
    cs = clients(others, 1)

    def churn(cl):
        mine = []
        for k in range(10):
            cid = uuid7()
            cl.call("add_comment", p_id=cid, p_post=post, p_texto=f"comentario {k}")
            mine.append(cid)
            if rnd.random() < 0.4:
                cl.call("delete_comment", p_id=mine.pop(rnd.randrange(len(mine))))

    o = run_parallel([lambda cl=cl: churn(cl) for cl in cs], 40)
    no_unexpected(o)
    stored, real = q("""select p.comentarios_count, (select count(*) from feed.comments c where c.post_id=p.id)
                          from feed.posts p where p.id=%s""", post)[0]
    check(stored == real, f"comentarios_count exacto ({stored} = {real})")
    close(cs)


def make_club(organizer: str) -> str:
    club = str(uuid7())
    q("""insert into clubs.clubs (id, nombre, ciudad, pais, ubicacion)
         values (%s, %s, 'Madrid', 'España', extensions.st_point(-3.70, 40.41)::extensions.geography)""",
      club, f"Stress {RUN} club")
    q("insert into clubs.club_members (club_id, user_id, rol) values (%s, %s, 'organizador')", club, organizer)
    return club


@scenario
def club_membership_storm():
    ids = create_members(50, "club")
    club = make_club(ids[0])
    cs = clients(ids[1:], 1)

    def churn(cl):
        for _ in range(8):
            cl.call("join_club", p_club=club) if rnd.random() < 0.6 else cl.call("leave_club", p_club=club)

    o = run_parallel([lambda cl=cl: churn(cl) for cl in cs], 49)
    no_unexpected(o)
    stored, real = q("""select c.miembros_count, (select count(*) from clubs.club_members m where m.club_id=c.id)
                          from clubs.clubs c where c.id=%s""", club)[0]
    check(stored == real, f"miembros_count exacto ({stored} = {real})")
    close(cs)


# ------------------------------------------------------------------- eventos ----------

EVENT_INVARIANTS = """
  select e.aforo, e.inscritos_count,
         (select count(*) from clubs.event_attendees a where a.event_id=e.id and a.estado='inscrito'),
         (select count(*) from clubs.event_attendees a where a.event_id=e.id and a.estado='lista_espera')
    from clubs.events e where e.id=%s"""


def check_event(ev, label):
    aforo, stored, inscritos, espera = q(EVENT_INVARIANTS, ev)[0]
    check(stored == inscritos, f"{label}: inscritos_count exacto ({stored} = {inscritos})")
    check(inscritos <= aforo, f"{label}: sin overbooking ({inscritos} ≤ {aforo})")
    check(espera == 0 or inscritos == aforo,
          f"{label}: no quedan plazas libres con gente en espera ({inscritos}/{aforo}, espera {espera})")


@scenario
def event_capacity_race():
    """Aforo 10, 60 inscripciones simultáneas; luego bajas y altas cruzadas."""
    ids = create_members(81, "ev")
    club = make_club(ids[0])
    org = Client(ids[0])
    ev = uuid7()
    org.call("create_event", p_id=ev, p_club=club, p_titulo="Afterwork estrés",
             p_inicio=datetime.now(timezone.utc) + timedelta(days=3), p_aforo=10)
    org.close()
    first, later = ids[1:61], ids[61:]
    cs = {i: Client(i) for i in ids[1:]}
    o = run_parallel([lambda i=i: cs[i].call("register_event", p_event=ev) for i in first], 60)
    no_unexpected(o)
    check_event(ev, "tras 60 altas")

    inscritos = [r[0] for r in q("select user_id::text from clubs.event_attendees where event_id=%s and estado='inscrito'", ev)]
    espera = [r[0] for r in q("select user_id::text from clubs.event_attendees where event_id=%s and estado='lista_espera'", ev)]
    tasks = [lambda i=i: cs[i].call("cancel_event_registration", p_event=ev) for i in inscritos[:8]]
    tasks += [lambda i=i: cs[i].call("cancel_event_registration", p_event=ev) for i in espera[:10]]
    tasks += [lambda i=i: cs[i].call("register_event", p_event=ev) for i in later]
    tasks += [lambda i=i: cs[i].call("register_event", p_event=ev) for i in inscritos[:4]]  # vuelven a apuntarse
    rnd.shuffle(tasks)
    o = run_parallel(tasks, len(tasks))
    no_unexpected(o)
    check_event(ev, "tras bajas y altas cruzadas")

    # Vaciar del todo en paralelo: nadie queda en espera con plazas libres.
    everyone = [r[0] for r in q("select user_id::text from clubs.event_attendees where event_id=%s", ev)]
    drop = everyone[: len(everyone) - 5]
    o = run_parallel([lambda i=i: cs[i].call("cancel_event_registration", p_event=ev) for i in drop], len(drop))
    no_unexpected(o)
    check_event(ev, "tras vaciado masivo")
    close(cs.values())


# ------------------------------------------------------------------ orientador --------

@scenario
def orientador_daily_limit_race():
    ids = create_members(3, "ori")
    limit = int(q1("select (config.get('orientador.daily_limit', '10'))::int"))
    for u in ids:
        cs = clients([u], 30)
        o = run_parallel([lambda cl=cl: cl.call("orientador_reserve", p_id=uuid7(), p_fase="exploracion",
                                                p_pais="México", p_sector="Agroalimentario", p_consulta="¿?")
                          for cl in cs], 30)
        no_unexpected(o, {"P0001"})
        check(o.ok == limit, f"exactamente {limit} consultas aceptadas de 30 simultáneas ({o.ok})")
        close(cs)


# ---------------------------------------------------------------------- colas ---------

@scenario
def queue_exactly_once():
    """8 consumidores (push-dispatcher en paralelo) leen la misma cola: nadie procesa dos veces."""
    total = 600
    q("select pgmq.send_batch('push', array(select jsonb_build_object('stress', %s::text, 'n', g) "
      "from generate_series(1, %s) g))", RUN, total)
    seen: dict[int, int] = {}
    lock = threading.Lock()
    workers = [Client(None, role="service_role") for _ in range(8)]

    def consume(cl):
        idle = 0
        while idle < 3:
            batch = cl.call("svc_queue_read", p_queue="push", p_qty=37, p_vt=60)
            mine = [m["msg_id"] for m in batch if m["message"].get("stress") == RUN]
            if not batch:
                idle += 1
                time.sleep(0.02)
                continue
            idle = 0
            if not mine:
                continue
            with lock:
                for m in mine:
                    seen[m] = seen.get(m, 0) + 1
            cl.call("svc_queue_ack", p_queue="push", p_ids=mine)

    o = run_parallel([lambda cl=cl: consume(cl) for cl in workers], 8)
    no_unexpected(o)
    check(len(seen) == total, f"todos los mensajes consumidos ({len(seen)}/{total})")
    check(all(v == 1 for v in seen.values()), "ningún mensaje entregado dos veces")
    left = q1("select count(*) from pgmq.q_push where message->>'stress' = %s", RUN)
    check(left == 0, "cola vacía tras el ack")
    close(workers)


# ----------------------------------------------------------------- paginación ---------

@scenario
def feed_pagination_under_writes():
    """Paginar el feed mientras otros publican: sin duplicados ni huecos en lo ya existente."""
    ids = create_members(13, "pag")
    reader, writers = ids[0], ids[1:]
    rc = Client(reader)
    for w in writers:
        rc.call("follow", p_user=w)
    wc = clients(writers, 1)
    for cl in wc:
        for k in range(15):
            cl.call("create_post", p_id=uuid7(), p_texto=f"previo {k}")
    before = {r[0] for r in q("select id::text from feed.posts where autor_id = any(%s)", writers)}
    stop = threading.Event()

    def write(cl):
        while not stop.is_set():
            cl.call("create_post", p_id=uuid7(), p_texto="nuevo durante la paginación")

    threads = [threading.Thread(target=write, args=(cl,)) for cl in wc]
    for t in threads:
        t.start()
    seen, cursor, dupes = [], None, 0
    while True:
        page = rc.call("get_feed", p_cursor=cursor, p_limit=17)
        for it in page["items"]:
            if it["id"] in seen:
                dupes += 1
            seen.append(it["id"])
        cursor = page["next_cursor"]
        if not cursor:
            break
    stop.set()
    for t in threads:
        t.join()
    check(dupes == 0, "sin duplicados entre páginas")
    missing = before - set(seen)
    check(not missing, f"todos los posts previos aparecen ({len(before) - len(missing)}/{len(before)})")
    close(wc + [rc])


# ------------------------------------------------------------------ caos mixto ---------

@scenario
def mixed_chaos():
    """32 conexiones durante 20 s haciendo de todo a la vez. Ningún deadlock ni error 5xx."""
    ids = create_members(40, "chaos")
    club = make_club(ids[0])
    org = Client(ids[0])
    ev = uuid7()
    org.call("create_event", p_id=ev, p_club=club, p_titulo="Evento caótico",
             p_inicio=datetime.now(timezone.utc) + timedelta(days=5), p_aforo=7)
    posts = []
    for k in range(5):
        p = uuid7()
        Client(ids[k]).call("create_post", p_id=p, p_texto=f"post caos {k}")
        posts.append(p)
    org.close()
    convs: dict[str, list[str]] = {}
    deadline = time.time() + float(__import__("os").environ.get("CHAOS_SECONDS", "20"))
    allowed = {"42501", "P0001", "22023"}  # bloqueado / límite / datos no válidos esperables
    o = Outcome()
    ops = {"n": 0}
    lock = threading.Lock()

    def worker(seed):
        cl = Client(ids[seed % len(ids)])
        r = __import__("random").Random(seed)
        while time.time() < deadline:
            op = r.randrange(14)
            other = r.choice(ids)
            try:
                if op == 0 and other != cl.user_id:
                    res = cl.call("send_message", p_id=uuid7(), p_cuerpo="caos", p_to=other)
                    with lock:
                        for u in (cl.user_id, other):
                            convs.setdefault(u, []).append(res["conversation_id"])
                elif op == 1:
                    cl.call("recommend", p_post=r.choice(posts))
                elif op == 2:
                    cl.call("unrecommend", p_post=r.choice(posts))
                elif op == 3 and other != cl.user_id:
                    cl.call("follow", p_user=other)
                elif op == 4:
                    cl.call("unfollow", p_user=other)
                elif op == 5:
                    cl.call("add_comment", p_id=uuid7(), p_post=r.choice(posts), p_texto="caos")
                elif op == 6:
                    cl.call("register_event", p_event=ev)
                elif op == 7:
                    cl.call("cancel_event_registration", p_event=ev)
                elif op == 8:
                    cl.call("get_feed", p_limit=20)
                elif op == 9:
                    cl.call("list_conversations")
                elif op == 10:
                    cl.call("unread_counts")
                elif op == 11 and convs.get(cl.user_id):
                    c = r.choice(convs[cl.user_id])
                    last = q1("select id from messaging.messages where conversation_id=%s order by id desc limit 1", c)
                    if last:
                        cl.call("mark_read", p_conversation=c, p_message_id=last)
                elif op == 12:
                    cl.call("search_directory", p_query=r.choice(["ana", "mar", "stress", None]))
                elif op == 13:
                    cl.call("join_club", p_club=club) if r.random() < .5 else cl.call("leave_club", p_club=club)
                o.success()
            except Exception as e:  # noqa: BLE001
                o.failure(e)
            with lock:
                ops["n"] += 1
        cl.close()

    threads = [threading.Thread(target=worker, args=(s,)) for s in range(32)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    print(f"    · {ops['n']} operaciones, {o.ok} correctas, errores {o.errors} {o.samples}")
    no_unexpected(o, allowed)
    check(not {"40P01", "40001"} & set(o.errors), "ningún deadlock ni fallo de serialización")
    check_global_invariants(ids)
    check_event(ev, "evento caótico")


def check_global_invariants(ids):
    bad_profiles = q1("""select count(*) from profiles.profiles p where p.user_id = any(%s) and (
        p.seguidores_count <> (select count(*) from social.follows f where f.seguido_id = p.user_id) or
        p.siguiendo_count <> (select count(*) from social.follows f where f.seguidor_id = p.user_id))""", ids)
    check(bad_profiles == 0, "contadores de seguidores exactos")
    bad_posts = q1("""select count(*) from feed.posts p where p.autor_id = any(%s) and (
        p.recomendaciones_count <> (select count(*) from feed.recommendations r where r.post_id = p.id) or
        p.comentarios_count <> (select count(*) from feed.comments c where c.post_id = p.id))""", ids)
    check(bad_posts == 0, "contadores de posts exactos")
    bad_clubs = q1("""select count(*) from clubs.clubs c where c.nombre like %s and
        c.miembros_count <> (select count(*) from clubs.club_members m where m.club_id = c.id)""", f"Stress {RUN}%")
    check(bad_clubs == 0, "contadores de clubs exactos")
    bad_unread = q1("""select count(*) from messaging.conversation_members cm where cm.user_id = any(%s)
        and cm.no_leidos < (select count(*) from messaging.messages m
              where m.conversation_id = cm.conversation_id and m.remitente_id <> cm.user_id
                and (cm.ultimo_leido_id is null or m.id > cm.ultimo_leido_id))""", ids)
    check(bad_unread == 0, "no_leidos nunca por debajo de lo pendiente en ninguna conversación")
    bad_last = q1("""select count(*) from messaging.conversations c
        where exists (select 1 from messaging.conversation_members m where m.conversation_id = c.id and m.user_id = any(%s))
          and c.ultimo_mensaje_id is distinct from (select x.id from messaging.messages x where x.conversation_id = c.id order by id desc limit 1)""",
                  ids)
    check(bad_last == 0, "último mensaje de cada conversación correcto")
    dup_groups = q1("""select count(*) from (select user_id, group_key from notifications.notifications
        where user_id = any(%s) and not leido and group_key is not null group by 1, 2 having count(*) > 1) t""", ids)
    check(dup_groups == 0, "sin notificaciones agrupadas duplicadas")


@scenario
def content_deleted_during_interaction():
    """El autor borra posts mientras 30 socios los recomiendan, comentan y comparten."""
    ids = create_members(31, "cdel")
    author, others = ids[0], ids[1:]
    ac = Client(author)
    cs = clients(others, 1)
    allowed = {"P0002", "42501"}
    total = Outcome()
    for round_ in range(10):
        post = uuid7()
        ac.call("create_post", p_id=post, p_texto=f"efímero {round_}")

        def interact(cl, post=post):
            for _ in range(4):
                r = rnd.random()
                try:
                    if r < .4:
                        cl.call("recommend", p_post=post)
                    elif r < .8:
                        cl.call("add_comment", p_id=uuid7(), p_post=post, p_texto="rápido")
                    else:
                        cl.call("create_post", p_id=uuid7(), p_texto="lo comparto", p_compartido_de=post)
                    total.success()
                except Exception as e:  # noqa: BLE001
                    total.failure(e)
                time.sleep(0.003)

        tasks = [lambda cl=cl: interact(cl) for cl in cs] + [lambda: ac.call("delete_post", p_id=post)]
        rnd.shuffle(tasks)
        run_parallel(tasks, len(tasks), total)
    print(f"    · {total.ok} correctas, errores controlados {total.errors}")
    no_unexpected(total, allowed)
    check(q1("select count(*) from feed.recommendations r where not exists (select 1 from feed.posts p where p.id=r.post_id)") == 0,
          "sin recomendaciones huérfanas")
    # Reintentos simultáneos de la misma publicación: una sola fila, ningún error.
    pid = uuid7()
    rc = clients([author], 16)
    o = run_parallel([lambda cl=cl: cl.call("create_post", p_id=pid, p_texto="reintento") for cl in rc], 16)
    no_unexpected(o, label="create_post reintentado: ")
    check(q1("select count(*) from feed.posts where id=%s", pid) == 1, "create_post idempotente en paralelo")
    # Un club que se borra mientras la gente se une.
    club = make_club(author)
    jc = clients(others, 1)
    o = run_parallel([lambda cl=cl: cl.call("join_club", p_club=club) for cl in jc]
                     + [lambda: q("delete from clubs.clubs where id=%s", club)], 31)
    no_unexpected(o, allowed, "club borrado: ")
    close(cs + rc + jc + [ac])


@scenario
def partition_maintenance_in_parallel():
    """El cron de particiones lanzado varias veces a la vez mientras se escriben mensajes."""
    a, b = create_members(2, "part")
    ca = Client(a)
    conv = ca.call("send_message", p_id=uuid7(), p_cuerpo="hola", p_to=b)["conversation_id"]
    svc = [Client(None, role="service_role") for _ in range(8)]
    writers = clients([a], 4)

    def write(cl):
        for _ in range(20):
            cl.call("send_message", p_id=uuid7(), p_cuerpo="mientras se mantiene", p_conversation_id=conv)

    def maintain(cl):
        with cl.conn.cursor() as cur:
            cur.execute("select messaging.ensure_partitions('2033-01-01', 6)")

    o = run_parallel([lambda cl=cl: maintain(cl) for cl in svc] + [lambda cl=cl: write(cl) for cl in writers], 12)
    no_unexpected(o)
    n = q1("select count(*) from pg_class where relname like 'messages_2033_%%' and relkind = 'r'")
    check(n == 6, f"6 particiones creadas una sola vez ({n})")
    for (t,) in q("select relname from pg_class where relname like 'messages_2033_%%' and relkind = 'r'"):
        q(f"drop table messaging.{t}")
    close(svc + writers + [ca])


@scenario
def account_deletion_during_activity():
    """Un socio borra su cuenta mientras otros le escriben, recomiendan y siguen."""
    ids = create_members(21, "del")
    victim, others = ids[0], ids[1:]
    post = uuid7()
    vc = Client(victim)
    vc.call("create_post", p_id=post, p_texto="me voy")
    cs = clients(others, 1)
    for cl in cs[:5]:
        cl.call("send_message", p_id=uuid7(), p_cuerpo="hola", p_to=victim)

    def activity(cl):
        for _ in range(15):
            r = rnd.random()
            if r < .3:
                cl.call("recommend", p_post=post)
            elif r < .6:
                cl.call("follow", p_user=victim)
            elif r < .8:
                cl.call("add_comment", p_id=uuid7(), p_post=post, p_texto="adiós")
            else:
                cl.call("send_message", p_id=uuid7(), p_cuerpo="¿sigues?", p_to=victim)

    def delete():
        time.sleep(0.03)
        vc.call("delete_my_account", p_confirmacion="BORRAR MI CUENTA")

    o = run_parallel([lambda cl=cl: activity(cl) for cl in cs] + [delete], 21)
    # Tras el borrado, actuar sobre algo que ya no existe debe dar un error controlado
    # (no encontrado / no permitido), nunca un 500 ni datos huérfanos.
    no_unexpected(o, {"42501", "P0002", "22023"})
    check(q1("select count(*) from identity.members where user_id=%s", victim) == 0, "cuenta borrada")
    check(q1("select count(*) from social.follows where seguido_id=%s or seguidor_id=%s", victim, victim) == 0,
          "sin seguimientos huérfanos")
    check(q1("select count(*) from messaging.messages where remitente_id=%s", victim) == 0, "sin mensajes del socio borrado")
    check_global_invariants(others)
    close(cs + [vc])


def main(argv):
    names = argv or list(SCENARIOS)
    t0 = time.time()
    try:
        for name in names:
            print(f"▶ {name}")
            t = time.time()
            try:
                SCENARIOS[name]()
            except Exception as e:  # noqa: BLE001
                FAILURES.append(f"{name}: excepción {e!r}")
                print(f"    ✗ excepción {e!r}")
            print(f"    ({time.time() - t:.1f} s)")
    finally:
        cleanup()
    print(f"\n{len(names)} escenarios en {time.time() - t0:.0f} s — "
          f"{'OK' if not FAILURES else f'{len(FAILURES)} FALLOS'}")
    for f in FAILURES:
        print(f"  ✗ {f}")
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
