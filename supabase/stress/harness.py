"""Utilidades comunes de las pruebas de concurrencia y escalabilidad.

Cada «cliente» es una conexión real e independiente a Postgres que se identifica como
lo haría PostgREST: `role authenticated` + `request.jwt.claims` con el `sub` del socio.
Así las funciones `api.*` se ejecutan con RLS, triggers y bloqueos reales, en paralelo.
"""

from __future__ import annotations

import json
import os
import random
import secrets
import threading
import time
import traceback
import uuid
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field

import psycopg
from psycopg.rows import tuple_row

DB_URL = os.environ.get("DB_URL", "postgresql://postgres:postgres@127.0.0.1:54322/postgres")
RUN = secrets.token_hex(3)  # etiqueta de esta ejecución (limpieza segura)


def uuid7() -> uuid.UUID:
    """UUID v7 (ordenable por tiempo), como genera la app con `Uuid().v7()`."""
    ms = time.time_ns() // 1_000_000
    rand = int.from_bytes(os.urandom(10), "big")
    value = (ms & ((1 << 48) - 1)) << 80
    value |= 0x7 << 76
    value |= ((rand >> 62) & 0xFFF) << 64
    value |= 0b10 << 62
    value |= rand & ((1 << 62) - 1)
    return uuid.UUID(int=value)


def admin() -> psycopg.Connection:
    return psycopg.connect(DB_URL, autocommit=True, row_factory=tuple_row)


class Client:
    """Conexión propia de un socio. Cada llamada es su propia transacción (como PostgREST)."""

    def __init__(self, user_id: str | None, role: str = "authenticated"):
        self.user_id = user_id
        self.conn = psycopg.connect(DB_URL, autocommit=True)
        claims = {"role": role}
        if user_id:
            claims |= {"sub": str(user_id), "aud": "authenticated"}
        with self.conn.cursor() as cur:
            cur.execute("select set_config('request.jwt.claims', %s, false)", (json.dumps(claims),))
            cur.execute(f"set role {role}")
            cur.execute("set statement_timeout = '20s'")

    def call(self, fn: str, **kwargs):
        args = ", ".join(f"{k} => %({k})s" for k in kwargs)
        with self.conn.cursor() as cur:
            cur.execute(f"select api.{fn}({args})", kwargs)
            row = cur.fetchone()
            return row[0] if row else None

    def close(self):
        self.conn.close()


def create_members(n: int, prefix: str = "m") -> list[str]:
    ids = [str(uuid.uuid4()) for _ in range(n)]
    with admin() as c, c.cursor() as cur:
        cur.executemany(
            """insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data,
                 raw_user_meta_data, created_at, updated_at)
               values (%s, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
                 %s, '{"provider":"custom:icex-alumni"}', %s, now(), now())""",
            [
                (
                    i,
                    f"stress-{RUN}-{prefix}{k}@stress.invalid",
                    json.dumps({
                        "name": f"Stress {prefix}{k}",
                        "sub": f"stress-{RUN}-{i}",
                        "custom_claims": {"icex_member_verified": True, "icex_promocion": 40 + k % 10},
                    }),
                )
                for k, i in enumerate(ids)
            ],
        )
    return ids


def cleanup():
    with admin() as c, c.cursor() as cur:
        cur.execute("delete from messaging.messages where remitente_id in "
                    "(select id from auth.users where email like %s)", (f"stress-{RUN}-%",))
        cur.execute("delete from messaging.conversations c where not exists "
                    "(select 1 from messaging.conversation_members m where m.conversation_id = c.id)")
        cur.execute("delete from clubs.clubs where nombre like %s", (f"Stress {RUN}%",))
        cur.execute("delete from auth.users where email like %s", (f"stress-{RUN}-%",))


@dataclass
class Outcome:
    ok: int = 0
    errors: dict[str, int] = field(default_factory=dict)
    samples: dict[str, str] = field(default_factory=dict)
    lock: threading.Lock = field(default_factory=threading.Lock)

    def success(self):
        with self.lock:
            self.ok += 1

    def failure(self, e: Exception):
        code = getattr(e, "sqlstate", None) or type(e).__name__
        with self.lock:
            self.errors[code] = self.errors.get(code, 0) + 1
            self.samples.setdefault(code, str(e).splitlines()[0][:200])

    def unexpected(self, allowed: set[str] = frozenset()) -> dict[str, int]:
        return {k: v for k, v in self.errors.items() if k not in allowed}


def run_parallel(tasks, workers: int, outcome: Outcome | None = None) -> Outcome:
    """Lanza todas las tareas a la vez (barrera) y recoge éxitos y errores por SQLSTATE."""
    outcome = outcome or Outcome()
    barrier = threading.Barrier(min(workers, len(tasks)) or 1)

    def wrap(task):
        try:
            try:
                barrier.wait(timeout=30)
            except threading.BrokenBarrierError:
                pass
            task()
            outcome.success()
        except psycopg.Error as e:
            outcome.failure(e)
        except Exception as e:  # noqa: BLE001
            outcome.failure(e)
            traceback.print_exc()

    with ThreadPoolExecutor(max_workers=workers) as pool:
        list(pool.map(wrap, tasks))
    return outcome


def q(sql: str, *params):
    with admin() as c, c.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall() if cur.description else None


def q1(sql: str, *params):
    rows = q(sql, *params)
    return rows[0][0] if rows else None


rnd = random.Random(int(os.environ.get("STRESS_SEED", "20261124")))
