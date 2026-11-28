#!/usr/bin/env python3
"""Pruebas de escalabilidad: comunidad sintética grande + latencias reales por endpoint.

1. Genera (en SQL, en segundos) una comunidad etiquetada: N socios con perfiles y
   ubicaciones, seguimientos, posts, recomendaciones, comentarios, conversaciones con
   mensajes y notificaciones. Tamaño con SCALE (1 = 30.000 socios, ~4 M de filas).
2. Mide p50/p95 de cada endpoint como socios reales (RLS incluida), primero en serie y
   luego con 24 conexiones en paralelo (throughput y p95 bajo carga).
3. Revisa los planes de ejecución: ningún Seq Scan sobre tablas grandes en rutas calientes.
4. Borra todo lo generado (salvo KEEP=1).

Uso:  python3 supabase/stress/scale.py            # SCALE=1
      SCALE=0.2 python3 supabase/stress/scale.py  # rápido (CI)
"""

from __future__ import annotations

import os
import re
import statistics
import sys
import threading
import time

from harness import Client, admin, q, q1

SCALE = float(os.environ.get("SCALE", "1"))
N = max(2000, int(30000 * SCALE))
TAG = "scale-"
P95_BUDGET_MS = float(os.environ.get("P95_BUDGET_MS", "200"))
LOAD_P95_BUDGET_MS = float(os.environ.get("LOAD_P95_BUDGET_MS", "600"))
FAILURES: list[str] = []


def check(cond, msg):
    print(("    ✓ " if cond else "    ✗ ") + msg)
    if not cond:
        FAILURES.append(msg)


def generate():
    t0 = time.time()
    if q1("select count(*) from profiles.profiles where slug like 'escala-%%'") >= N:
        print(f"  · reutilizando comunidad sintética existente ({N} socios)")
        return
    cleanup()
    with admin() as c, c.cursor() as cur:
        cur.execute("set session_replication_role = replica")   # sin triggers: carga masiva
        cur.execute("set work_mem = '256MB'")
        cur.execute("select setseed(0.42)")
        steps = [
            ("socios", f"""
             create temp table g_users as
             select g as n, gen_random_uuid() as id from generate_series(1, {N}) g;
             insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
             select id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
                    '{TAG}' || n || '@scale.invalid', '{{"provider":"custom:icex-alumni"}}',
                    jsonb_build_object('name', 'Escala ' || n, 'custom_claims', jsonb_build_object('icex_member_verified', true)),
                    now(), now() from g_users;
             insert into identity.members (user_id, wp_subject, status) select id, '{TAG}' || n, 'active' from g_users;
             insert into notifications.preferences (user_id) select id from g_users on conflict do nothing;"""),
            ("perfiles", """
             insert into profiles.profiles (user_id, slug, nombre, cargo, empresa, fase, promocion, pais, pais_code,
                                            ciudad, sector, ubicacion)
             select u.id, 'escala-' || u.n,
                    (array['Ana','Javier','Laura','Pedro','Lucía','Carlos','Marta','Diego','Sara','Hugo'])[1 + u.n % 10]
                      || ' ' || (array['García','Martín','López','Sánchez','Pérez','Gómez','Ruiz','Díaz','Moreno','Álvarez'])[1 + (u.n / 10) % 10]
                      || ' ' || u.n,
                    (array['Export Manager','Consultora','Directora comercial','Analista','CEO'])[1 + u.n % 5],
                    (array['Sener','Indra','Iberdrola','Inditex','Telefónica','ICEX','Mercadona','Repsol'])[1 + u.n % 8],
                    (array['activo','fase_0','fase_1','fase_2']::profiles.fase[])[1 + u.n % 4],
                    1 + u.n % 60,
                    c.pais, c.code, c.ciudad,
                    (array['Agroalimentario','Energía','Tecnología','Moda','Consultoría'])[1 + u.n % 5],
                    extensions.st_point(c.lng + (random() - .5) * .2, c.lat + (random() - .5) * .2)::extensions.geography
               from g_users u
               cross join lateral (select * from (values
                 ('España','ES','Madrid',-3.70,40.41), ('España','ES','Barcelona',2.17,41.38),
                 ('México','MX','Ciudad de México',-99.13,19.43), ('China','CN','Shanghái',121.47,31.23),
                 ('EE. UU.','US','Nueva York',-74.0,40.71), ('Francia','FR','París',2.35,48.85),
                 ('Singapur','SG','Singapur',103.82,1.35), ('Brasil','BR','São Paulo',-46.63,-23.55),
                 ('Marruecos','MA','Casablanca',-7.59,33.57), ('Alemania','DE','Berlín',13.40,52.52))
                 v(pais, code, ciudad, lng, lat) offset (u.n % 10) limit 1) c;"""),
            ("seguimientos", f"""
             insert into social.follows (seguidor_id, seguido_id, created_at)
             select distinct on (a.id, b.id) a.id, b.id, now() - random() * interval '300 days'
               from g_users a
               cross join lateral generate_series(1, 5 + (a.n % 70)) k
               join g_users b on b.n = 1 + ((a.n * 7919 + k * 104729) % {N})
              where b.id <> a.id
             on conflict do nothing;"""),
            ("posts", """
             create temp table g_posts as
             select gen_random_uuid() as id, u.id as autor, now() - random() * interval '365 days' as ts
               from g_users u cross join lateral generate_series(1, (u.n % 13)) k;
             insert into feed.posts (id, autor_id, texto, created_at, updated_at)
             select id, autor, 'Post sintético de escala con algo de texto para pesar como uno real. ' || id, ts, ts
               from g_posts;"""),
            ("recomendaciones", f"""
             insert into feed.recommendations (post_id, user_id, created_at)
             select p.id, u.id, p.ts + interval '1 hour'
               from (select id, ts, row_number() over () rn from g_posts) p
               cross join lateral generate_series(1, (p.rn % 9)::int) k
               join g_users u on u.n = 1 + ((p.rn * 31 + k * 977) % {N})
             on conflict do nothing;"""),
            ("comentarios", f"""
             insert into feed.comments (post_id, autor_id, texto, created_at)
             select p.id, u.id, 'Comentario de escala', p.ts + interval '2 hours'
               from (select id, ts, row_number() over () rn from g_posts) p
               cross join lateral generate_series(1, (p.rn % 3)::int) k
               join g_users u on u.n = 1 + ((p.rn * 17 + k * 131) % {N});"""),
            ("conversaciones y mensajes", f"""
             create temp table g_conv as
             select gen_random_uuid() as id, a.id as a, b.id as b
               from g_users a cross join generate_series(1, 4) k
               join g_users b on b.n = 1 + ((a.n * 13 + k) % {N})
              where a.n % 2 = 0 and a.id <> b.id;
             delete from g_conv x using g_conv y
              where messaging.direct_key(x.a, x.b) = messaging.direct_key(y.a, y.b) and x.ctid > y.ctid;
             insert into messaging.conversations (id, direct_key, creado_por)
             select id, messaging.direct_key(a, b), a from g_conv on conflict do nothing;
             insert into messaging.conversation_members (conversation_id, user_id)
             select id, a from g_conv union all select id, b from g_conv on conflict do nothing;
             insert into messaging.messages (id, conversation_id, remitente_id, cuerpo, created_at)
             select util.uuid_v7(now() - (k || ' minutes')::interval * (1 + abs(hashtext(c.id::text)) % 500)),
                    c.id, case when k % 2 = 0 then c.a else c.b end, 'Mensaje ' || k,
                    now() - (k || ' minutes')::interval * (1 + abs(hashtext(c.id::text)) % 500)
               from g_conv c cross join lateral generate_series(1, 1 + abs(hashtext(c.id::text)) % 30) k;
             update messaging.conversations c set ultimo_mensaje_id = l.id, ultimo_mensaje_en = l.created_at,
                    ultimo_mensaje_preview = l.cuerpo
               from g_conv g cross join lateral (select m.id, m.created_at, m.cuerpo from messaging.messages m
                                                  where m.conversation_id = g.id order by m.id desc limit 1) l
              where c.id = g.id;"""),
            ("notificaciones", """
             insert into notifications.notifications (user_id, tipo, actor_ids, payload, leido, created_at, updated_at)
             select u.id, 'nuevo_seguidor', array[u.id], '{}', k > 3, now() - k * interval '1 day', now() - k * interval '1 day'
               from g_users u cross join generate_series(1, 15) k;"""),
            ("contadores", """
             analyze profiles.profiles, social.follows, feed.posts, feed.recommendations, feed.comments,
                     messaging.messages, messaging.conversation_members;
             update profiles.profiles p set seguidores_count = coalesce(x.n, 0), siguiendo_count = coalesce(y.n, 0),
                    posts_count = coalesce(z.n, 0)
               from g_users u
               left join (select seguido_id id, count(*) n from social.follows group by 1) x on x.id = u.id
               left join (select seguidor_id id, count(*) n from social.follows group by 1) y on y.id = u.id
               left join (select autor_id id, count(*) n from feed.posts group by 1) z on z.id = u.id
              where p.user_id = u.id;
             update feed.posts x set recomendaciones_count = coalesce(r.n, 0), comentarios_count = coalesce(c.n, 0)
               from g_posts gp
               left join (select post_id id, count(*) n from feed.recommendations group by 1) r on r.id = gp.id
               left join (select post_id id, count(*) n from feed.comments group by 1) c on c.id = gp.id
              where x.id = gp.id;
             update messaging.conversation_members cm set no_leidos = coalesce(t.n, 0)
               from (select m.conversation_id, cm2.user_id, count(*) n
                       from g_conv g
                       join messaging.conversation_members cm2 on cm2.conversation_id = g.id
                       join messaging.messages m on m.conversation_id = g.id and m.remitente_id <> cm2.user_id
                      group by 1, 2) t
              where cm.conversation_id = t.conversation_id and cm.user_id = t.user_id;"""),
            ("estadísticas", "analyze;"),
        ]
        with c.transaction():
            for label, sql in steps[:-1]:
                t = time.time()
                cur.execute(sql)
                print(f"  · {label}: {time.time() - t:.1f} s")
        cur.execute(steps[-1][1])
    counts = q("""select (select count(*) from identity.members), (select count(*) from social.follows),
                         (select count(*) from feed.posts), (select count(*) from feed.recommendations),
                         (select count(*) from feed.comments), (select count(*) from messaging.conversations),
                         (select count(*) from messaging.messages), (select count(*) from notifications.notifications)""")[0]
    labels = ["socios", "seguimientos", "posts", "recomendaciones", "comentarios", "conversaciones", "mensajes",
              "notificaciones"]
    print("  · total en la base: " + ", ".join(f"{v:,} {k}".replace(",", ".") for k, v in zip(labels, counts)))
    print(f"  · generado en {time.time() - t0:.0f} s")


def cleanup():
    with admin() as c, c.cursor() as cur:
        cur.execute("set session_replication_role = replica")
        cur.execute("""create temp table d as select id from auth.users where email like %s""", (f"{TAG}%",))
        for sql in [
            "delete from messaging.messages m using messaging.conversation_members cm, d where cm.conversation_id = m.conversation_id and cm.user_id = d.id",
            "delete from messaging.conversations c using messaging.conversation_members cm, d where cm.conversation_id = c.id and cm.user_id = d.id",
            "delete from messaging.conversation_members cm using d where cm.user_id = d.id",
            "delete from feed.comments x using feed.posts p, d where x.post_id = p.id and p.autor_id = d.id",
            "delete from feed.comments x using d where x.autor_id = d.id",
            "delete from feed.recommendations x using feed.posts p, d where x.post_id = p.id and p.autor_id = d.id",
            "delete from feed.recommendations x using d where x.user_id = d.id",
            "delete from feed.posts x using d where x.autor_id = d.id",
            "delete from social.follows x using d where x.seguidor_id = d.id or x.seguido_id = d.id",
            "delete from notifications.notifications x using d where x.user_id = d.id",
            "delete from notifications.preferences x using d where x.user_id = d.id",
            "delete from profiles.profiles x using d where x.user_id = d.id",
            "delete from identity.members x using d where x.user_id = d.id",
            "delete from auth.users x using d where x.id = d.id",
        ]:
            cur.execute(sql)
        cur.execute("analyze")


# ------------------------------------------------------------------ medición -------

def sample_users(k):
    """Socios representativos: muchos seguidos, pocos, con muchas conversaciones…"""
    rows = q(f"""(select user_id::text from profiles.profiles where slug like 'escala-%%' order by siguiendo_count desc limit {k // 3})
                 union all
                 (select user_id::text from profiles.profiles where slug like 'escala-%%' order by md5(user_id::text) limit {k - k // 3})""")
    return [r[0] for r in rows]


def endpoints(cl: Client, i: int):
    conv = q1("""select conversation_id::text from messaging.conversation_members where user_id = %s
                 order by no_leidos desc limit 1""", cl.user_id)
    post = q1("select id::text from feed.posts where comentarios_count > 0 order by md5(id::text || %s) limit 1", str(i))
    city = [(-3.70, 40.41), (-99.13, 19.43), (121.47, 31.23), (2.35, 48.85)][i % 4]
    calls = {
        "get_feed": lambda: cl.call("get_feed", p_limit=20),
        "get_feed (pág. 2)": None,
        "search_directory (texto)": lambda: cl.call("search_directory", p_query=["garcía", "sener", "export", "madrid", "lu"][i % 5]),
        "search_directory (filtros)": lambda: cl.call("search_directory", p_promocion=1 + i % 60, p_tab="exterior"),
        "suggestions": lambda: cl.call("suggestions"),
        "community_highlights": lambda: cl.call("community_highlights"),
        "get_profile": lambda: cl.call("get_profile", p_user=cl.user_id),
        "get_user_posts": lambda: cl.call("get_user_posts", p_user=cl.user_id),
        "list_conversations": lambda: cl.call("list_conversations"),
        "get_messages": (lambda: cl.call("get_messages", p_conversation=conv)) if conv else None,
        "unread_counts": lambda: cl.call("unread_counts"),
        "list_notifications": lambda: cl.call("list_notifications"),
        "get_comments": (lambda: cl.call("get_comments", p_post=post)) if post else None,
        "map_clusters (mundo)": lambda: cl.call("map_clusters", p_zoom=2, p_west=-180, p_south=-60, p_east=180, p_north=75),
        "map_clusters (ciudad)": lambda: cl.call("map_clusters", p_zoom=11, p_west=city[0] - .3, p_south=city[1] - .2,
                                                 p_east=city[0] + .3, p_north=city[1] + .2),
        "alumni_near": lambda: cl.call("alumni_near", p_lat=city[1], p_lng=city[0]),
        "community_stats": lambda: cl.call("community_stats"),
        "me": lambda: cl.call("me"),
    }
    return calls


def timed(fn):
    t = time.perf_counter()
    r = fn()
    return (time.perf_counter() - t) * 1000, r


def measure_serial(users):
    lat: dict[str, list[float]] = {}
    for i, u in enumerate(users):
        cl = Client(u)
        for name, fn in endpoints(cl, i).items():
            if name == "get_feed (pág. 2)":
                continue
            if fn is None:
                continue
            ms, r = timed(fn)
            lat.setdefault(name, []).append(ms)
            if name == "get_feed" and r.get("next_cursor"):
                ms2, _ = timed(lambda: cl.call("get_feed", p_cursor=r["next_cursor"], p_limit=20))
                lat.setdefault("get_feed (pág. 2)", []).append(ms2)
        cl.close()
    return lat


def pct(xs, p):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(round(p / 100 * (len(xs) - 1))))]


def report(lat, budget, title):
    print(f"\n  {title}")
    print(f"  {'endpoint':32} {'n':>5} {'p50':>8} {'p95':>8} {'máx':>8}")
    for name, xs in sorted(lat.items()):
        p95 = pct(xs, 95)
        flag = "" if p95 < budget else "  ← supera el presupuesto"
        print(f"  {name:32} {len(xs):>5} {statistics.median(xs):>7.1f}  {p95:>7.1f}  {max(xs):>7.1f}{flag}")
    worst = max((pct(xs, 95), n) for n, xs in lat.items())
    check(worst[0] < budget, f"{title}: todos los p95 < {budget:.0f} ms (peor: {worst[1]} {worst[0]:.0f} ms)")


def measure_load(users, seconds=20, conns=24):
    lat: dict[str, list[float]] = {}
    errors: dict[str, int] = {}
    lock = threading.Lock()
    deadline = time.time() + seconds

    def worker(k):
        cl = Client(users[k % len(users)])
        calls = [(n, f) for n, f in endpoints(cl, k).items() if f is not None]
        j = k
        while time.time() < deadline:
            name, fn = calls[j % len(calls)]
            j += 1
            try:
                ms, _ = timed(fn)
                with lock:
                    lat.setdefault(name, []).append(ms)
            except Exception as e:  # noqa: BLE001
                with lock:
                    key = getattr(e, "sqlstate", None) or type(e).__name__
                    errors[key] = errors.get(key, 0) + 1
        cl.close()

    threads = [threading.Thread(target=worker, args=(k,)) for k in range(conns)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    total = sum(len(v) for v in lat.values())
    print(f"\n  · {conns} conexiones × {seconds} s: {total} llamadas ({total / seconds:.0f}/s), errores {errors}")
    check(not errors, "sin errores bajo carga")
    report(lat, LOAD_P95_BUDGET_MS, f"Bajo carga ({conns} conexiones en paralelo)")


# ------------------------------------------------------------------ planes ----------

# Recorridos completos revisados y aceptados (el planificador acierta: ver motivo).
ALLOWED_SEQ = {
    ("suggestions", "profiles"): "une ~1.500 candidatos; un hash join con un recorrido es más barato que 1.500 búsquedas",
}

HOT = ["feed.posts", "social.follows", "feed.recommendations", "feed.comments", "messaging.messages",
       "messaging.conversation_members", "notifications.notifications", "profiles.profiles"]


def check_plans(user):
    """EXPLAIN de las funciones como socio, con auto_explain sobre las sentencias internas."""
    cl = Client(user)
    found = []
    with cl.conn.cursor() as cur:
        cur.execute("reset role")
        cur.execute("set auto_explain.log_min_duration = 0")
        cur.execute("set auto_explain.log_nested_statements = on")
        cur.execute("set auto_explain.log_analyze = on")
        cur.execute("set client_min_messages = log")
        cur.execute("set auto_explain.log_level = notice")
        cur.execute("set role authenticated")
        notices = []
        cl.conn.add_notice_handler(lambda d: notices.append(d.message_primary))
        for name, fn in endpoints(cl, 1).items():
            if fn is None:
                continue
            notices.clear()
            fn()
            for n in notices:
                for m in re.finditer(r"Seq Scan on (\w+)(?: (\w+))?.*?rows=(\d+) loops=(\d+)", n):
                    table = m.group(1)
                    rows_scanned = int(m.group(3)) * int(m.group(4))
                    if any(h.endswith("." + table) or h.split(".")[1] == table for h in HOT):
                        found.append((name, table, rows_scanned))
    cl.close()
    for name, table, rows in found:
        print(f"    · {name}: Seq Scan sobre {table} ({rows} filas)")
    big = [(n, t) for n, t, _ in found
           if (n, t) not in ALLOWED_SEQ and q1("select reltuples from pg_class where relname = %s", t) > 10_000]
    for (n, t), why in ALLOWED_SEQ.items():
        if any(f[0] == n and f[1] == t for f in found):
            print(f"    · aceptado {n}/{t}: {why}")
    check(not big, "sin Seq Scan sobre tablas grandes en rutas calientes" + (f" ({big})" if big else ""))


def main():
    print(f"▶ Generando comunidad sintética (SCALE={SCALE}: {N:,} socios)".replace(",", "."))
    generate()
    users = sample_users(60)
    print("▶ Calentando cachés")
    measure_serial(users[:5])
    print("▶ Latencia en serie (60 socios distintos)")
    report(measure_serial(users), P95_BUDGET_MS, "En serie")
    print("▶ Latencia bajo carga")
    measure_load(users, seconds=int(os.environ.get("LOAD_SECONDS", "20")))
    print("▶ Planes de ejecución")
    check_plans(users[0])
    if os.environ.get("KEEP") != "1":
        print("▶ Limpiando")
        cleanup()
    print(f"\nEscalabilidad: {'OK' if not FAILURES else f'{len(FAILURES)} FALLOS'}")
    for f in FAILURES:
        print(f"  ✗ {f}")
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())
