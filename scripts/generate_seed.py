#!/usr/bin/env python3
"""Genera supabase/seed.sql: comunidad de demostración ficticia de ICEX Atlas.

Determinista (semilla fija). Uso:  python3 scripts/generate_seed.py > supabase/seed.sql
Todos los perfiles, publicaciones y conversaciones son ficticios (inspirados en el mockup).
Usuarios con login OIDC de pruebas (docker/oidc-provider): ana, javier, laura(admin).
"""
from __future__ import annotations

import random
import uuid

random.seed(51)  # 51 promociones


def uid() -> str:
    return str(uuid.UUID(int=random.getrandbits(128), version=4))


def q(s: str | None) -> str:
    if s is None:
        return "null"
    return "'" + s.replace("'", "''") + "'"


# ----------------------------------------------------------------- catálogos --
CITIES = [  # ciudad, país, código, lat, lng
    ("Madrid", "España", "ES", 40.42, -3.70), ("Barcelona", "España", "ES", 41.39, 2.17),
    ("Lima", "Perú", "PE", -12.05, -77.04), ("Toronto", "Canadá", "CA", 43.65, -79.38),
    ("Santiago", "Chile", "CL", -33.45, -70.67), ("Tokio", "Japón", "JP", 35.68, 139.69),
    ("Bogotá", "Colombia", "CO", 4.71, -74.07), ("Varsovia", "Polonia", "PL", 52.23, 21.01),
    ("Mumbai", "India", "IN", 19.08, 72.88), ("Miami", "EE. UU.", "US", 25.76, -80.19),
    ("Riad", "Arabia Saudí", "SA", 24.71, 46.68), ("Londres", "Reino Unido", "GB", 51.51, -0.13),
    ("Milán", "Italia", "IT", 45.46, 9.19), ("Singapur", "Singapur", "SG", 1.35, 103.82),
    ("Nueva Delhi", "India", "IN", 28.61, 77.21), ("Nueva York", "EE. UU.", "US", 40.71, -74.01),
    ("Bruselas", "Bélgica", "BE", 50.85, 4.35), ("Berlín", "Alemania", "DE", 52.52, 13.40),
    ("São Paulo", "Brasil", "BR", -23.55, -46.63), ("Buenos Aires", "Argentina", "AR", -34.60, -58.38),
    ("Ciudad de México", "México", "MX", 19.43, -99.13), ("París", "Francia", "FR", 48.86, 2.35),
    ("Ámsterdam", "Países Bajos", "NL", 52.37, 4.90), ("Shanghái", "China", "CN", 31.23, 121.47),
    ("Seúl", "Corea del Sur", "KR", 37.57, 126.98), ("Dubái", "EAU", "AE", 25.20, 55.27),
    ("Sídney", "Australia", "AU", -33.87, 151.21), ("Casablanca", "Marruecos", "MA", 33.57, -7.59),
    ("Lagos", "Nigeria", "NG", 6.52, 3.38), ("Johannesburgo", "Sudáfrica", "ZA", -26.20, 28.05),
    ("Estocolmo", "Suecia", "SE", 59.33, 18.07), ("Estambul", "Turquía", "TR", 41.01, 28.98),
    ("Yakarta", "Indonesia", "ID", -6.21, 106.85), ("Múnich", "Alemania", "DE", 48.14, 11.58),
]
CITY = {c[0]: c for c in CITIES}
# Pesos: España y grandes hubs concentran más alumni.
CITY_WEIGHTS = [14, 6, 3, 3, 3, 3, 3, 2, 3, 3, 2, 5, 3, 3, 2, 5, 4, 4, 3, 3, 4, 4, 3, 3, 2, 3, 2, 2, 1, 1, 2, 2, 1, 2]

FIRST_F = ["Ana", "Sara", "Inés", "Carmen", "Rocío", "Lucía", "Beatriz", "María", "Irene", "Julia", "Paula",
           "Elena", "Marta", "Blanca", "Patricia", "Laura", "Cristina", "Raquel", "Alicia", "Nerea", "Andrea", "Clara"]
FIRST_M = ["Javier", "Sergio", "Luis", "Andrés", "Rubén", "David", "Fernando", "Álvaro", "Adrián", "Íñigo",
           "Jorge", "Borja", "Carlos", "Alejandro", "Diego", "Miguel", "Gonzalo", "Daniel", "Pablo", "Mario", "Hugo", "Iker"]
SURN = ["Ortega", "Jiménez", "Sáez", "Gómez", "Molina", "Echevarría", "Castro", "Domínguez", "Fernández", "Rubio",
        "Martínez", "Marín", "Serrano", "Vázquez", "Hernández", "Arrieta", "Iglesias", "Torres", "Ruiz", "Pérez",
        "Romero", "Sánchez", "Gil", "Martín", "García", "López", "Álvarez", "Navarro", "Blanco", "Delgado", "Moreno"]
COMPANIES = ["ACS", "Repsol", "Cámara de Comercio de España", "CESCE", "Grupo Puig", "Indra", "Cepsa",
             "Técnicas Reunidas", "Acciona", "Navantia", "Ferrovial", "Freixenet", "Iberdrola", "Ebro Foods", "Sener",
             "Mercadona", "CAF", "Meliá Hotels", "Grifols", "Telefónica", "Talgo", "Gestamp",
             "Banco Interamericano de Desarrollo", "Naturgy", "Chupa Chups", "Siemens Gamesa", "Inditex", "BBVA"]
SECTOR_OF = {"ACS": "Infraestructuras", "Repsol": "Energía", "Cámara de Comercio de España": "Consultoría",
             "CESCE": "Banca", "Grupo Puig": "Moda", "Indra": "Tecnología", "Cepsa": "Energía",
             "Técnicas Reunidas": "Energía", "Acciona": "Infraestructuras", "Navantia": "Industria",
             "Ferrovial": "Infraestructuras", "Freixenet": "Agroalimentario", "Iberdrola": "Energía",
             "Ebro Foods": "Agroalimentario", "Sener": "Industria", "Mercadona": "Agroalimentario", "CAF": "Industria",
             "Meliá Hotels": "Turismo", "Grifols": "Salud", "Telefónica": "Tecnología", "Talgo": "Industria",
             "Gestamp": "Industria", "Banco Interamericano de Desarrollo": "Banca", "Naturgy": "Energía",
             "Chupa Chups": "Agroalimentario", "Siemens Gamesa": "Energía", "Inditex": "Moda", "BBVA": "Banca"}
ROLES_ACTIVO = ["Business Development Manager", "Responsable de Operaciones", "Investment Promotion Officer",
                "Consultor de Internacionalización", "Export Manager", "Country Manager",
                "Head of International Sales", "Trade Analyst", "Area Manager LATAM"]
OFICINAS = ["Lima", "Santiago", "Tokio", "Bogotá", "Varsovia", "Mumbai", "Miami", "Riad", "Londres", "Milán",
            "Singapur", "Nueva Delhi", "Nueva York", "Bruselas", "Berlín", "São Paulo", "Buenos Aires",
            "Ciudad de México", "París", "Shanghái", "Seúl", "Dubái", "Sídney", "Casablanca", "Estocolmo"]
BIOS = [
    "Me interesa conectar con alumni que trabajen en {sector} y compartir lo aprendido en {ciudad}.",
    "Abierto/a a conversaciones sobre mercados internacionales, mentoría y primeros pasos tras la beca.",
    "Llevo varios años en {ciudad}. Encantado/a de ayudar a quien prepare su llegada.",
    "Trabajo en desarrollo de negocio internacional. Escríbeme si exploras el sector de {sector}.",
]

# Perfiles con nombre propio (aparecen en el mockup): nombre, fase, promo, cargo, empresa, ciudad
NAMED = [
    ("Ana Ortega Jiménez", "activo", 49, "Business Development Manager", "ACS", "Lima"),
    ("Javier Martín Jiménez", "activo", 42, "Export Manager", "Sener", "Singapur"),
    ("Sergio Castro Ruiz", "activo", 44, "Consultor de Internacionalización", "Técnicas Reunidas", "Madrid"),
    ("Inés Domínguez Gil", "activo", 47, "Export Manager", "Mercadona", "Ámsterdam"),
    ("Jorge Álvarez Romero", "activo", 22, "Investment Promotion Officer", "CAF", "Madrid"),
    ("Borja Sánchez Romero", "fase_1", 50, None, None, "Nueva Delhi"),
    ("Carlos Ortega Fernández", "activo", 49, "Area Manager LATAM", "Meliá Hotels", "Ciudad de México"),
    ("Elena Sáez Romero", "activo", 30, "Head of International Sales", "Repsol", "Shanghái"),
    ("Sara Navarro Hernández", "fase_2", 50, "Export", "CAF", "Madrid"),
    ("Paula Álvarez Pérez", "fase_1", 50, None, None, "Santiago"),
    ("Alejandro Iglesias Castro", "activo", 49, "Trade Analyst", "Grifols", "Barcelona"),
    ("Diego Arrieta Marín", "fase_2", 50, "Export", "CESCE", "Madrid"),
    ("Carlos Martín Delgado", "activo", 22, "Consultor de Internacionalización", "Telefónica", "Bruselas"),
    ("Rocío Pérez Gómez", "fase_2", 49, "Compras", "CESCE", "Barcelona"),
    ("Álvaro Sánchez Moreno", "fase_2", 49, "Export", "Talgo", "Madrid"),
    ("Lucía Castro Hernández", "fase_2", 50, "Desarrollo de negocio", "Gestamp", "Casablanca"),
    ("Irene Blanco Rubio", "activo", 31, "Country Manager", "Banco Interamericano de Desarrollo", "Berlín"),
    ("Sergio Iglesias Martínez", "activo", 34, "Investment Promotion Officer", "Naturgy", "Ciudad de México"),
    ("Marta Serrano Marín", "activo", 3, "Area Manager LATAM", "Chupa Chups", "Buenos Aires"),
    ("Inés Castro Sáez", "fase_2", 50, "Compras", "CESCE", "Tokio"),
    ("María Martín García", "fase_1", 50, None, None, "Bruselas"),
    ("Blanca Navarro Castro", "activo", 13, "Trade Analyst", "Siemens Gamesa", "Nueva York"),
    ("Miguel Echevarría Arrieta", "activo", 46, "Trade Analyst", "Sener", "Seúl"),
    ("Carmen Rubio Marín", "activo", 38, "Head of International Sales", "Freixenet", "Londres"),
    ("Gonzalo López Jiménez", "activo", 41, "Country Manager", "Acciona", "Lagos"),
    ("Miguel Gómez Romero", "fase_2", 50, "Desarrollo de negocio", "Indra", "Madrid"),
    ("Julia Sánchez Rubio", "activo", 34, "Business Development Manager", "Cepsa", "Dubái"),
    ("Daniel López Álvarez", "activo", 24, "Responsable de Operaciones", "Cámara de Comercio de España", "Madrid"),
    ("Patricia Sánchez Delgado", "activo", 34, "Export Manager", "Iberdrola", "Londres"),
    ("Laura Gil Navarro", "activo", 28, "Responsable de Comunicación", "ICEX Alumni", "Madrid"),
]
LOGIN_USERS = {  # nombre → (sub OIDC, email ficticio, rol)
    "Ana Ortega Jiménez": ("ana", "ana.ortega@demo.icexalumni.invalid", "socio"),
    "Javier Martín Jiménez": ("javier", "javier.martin@demo.icexalumni.invalid", "socio"),
    "Laura Gil Navarro": ("laura", "laura.gil@demo.icexalumni.invalid", "admin"),
}


def slug(name: str, user: str) -> str:
    import unicodedata
    s = unicodedata.normalize("NFKD", name.lower()).encode("ascii", "ignore").decode()
    s = "-".join("".join(ch if ch.isalnum() else " " for ch in s).split())
    return f"{s[:60]}-{user.replace('-', '')[:8]}"


def make_role(fase: str, cargo: str | None, empresa: str | None, ciudad: str) -> tuple[str, str]:
    if fase == "fase_0":
        return "Becario/a ICEX", empresa or random.choice(["ICEX-CECO", "COFIDES"])
    if fase == "fase_1":
        return "Becario/a de Internacionalización", f"Oficina Económica y Comercial de España en {ciudad}"
    if fase == "fase_2":
        return f"Becario/a en prácticas · {cargo or random.choice(['Export', 'Compras', 'Desarrollo de negocio'])}", \
            empresa or random.choice(COMPANIES)
    return cargo or random.choice(ROLES_ACTIVO), empresa or random.choice(COMPANIES)


# ---------------------------------------------------------------- perfiles ----
people = []  # dicts
used_names = set()
for (name, fase, promo, cargo, empresa, ciudad) in NAMED:
    used_names.add(name)
    c, e = make_role(fase, cargo, empresa, ciudad)
    people.append(dict(id=uid(), name=name, fase=fase, promo=promo, cargo=c, empresa=e, ciudad=ciudad))

TARGET = 640
while len(people) < TARGET:
    female = random.random() < 0.52
    name = f"{random.choice(FIRST_F if female else FIRST_M)} {random.choice(SURN)} {random.choice(SURN)}"
    if name in used_names:
        continue
    used_names.add(name)
    r = random.random()
    if r < 0.06:
        fase, promo, ciudad = "fase_0", 51, "Madrid"
    elif r < 0.17:
        fase, promo = "fase_1", random.choice([50, 51])
        ciudad = random.choice(OFICINAS)
    elif r < 0.29:
        fase, promo = "fase_2", random.choice([49, 50])
        ciudad = random.choices([c[0] for c in CITIES], weights=CITY_WEIGHTS)[0]
    else:
        fase = "activo"
        promo = min(49, max(1, int(random.triangular(1, 49, 44))))
        ciudad = random.choices([c[0] for c in CITIES], weights=CITY_WEIGHTS)[0]
    c, e = make_role(fase, None, None, ciudad)
    people.append(dict(id=uid(), name=name, fase=fase, promo=promo, cargo=c, empresa=e, ciudad=ciudad))

by_name = {p["name"]: p for p in people}
ana = by_name["Ana Ortega Jiménez"]
laura = by_name["Laura Gil Navarro"]

out: list[str] = []
w = out.append
w("-- =============================================================================")
w("-- ICEX Atlas · seed.sql — COMUNIDAD DE DEMOSTRACIÓN (datos 100 % ficticios)")
w("-- Generado por scripts/generate_seed.py. No editar a mano.")
w("-- =============================================================================")
w("set session_replication_role = replica;  -- sin triggers de notificación/cola durante la carga masiva")
w("begin;")

# auth.users + identity.members + profiles (insert directo; los triggers están desactivados)
w("\n-- Usuarios de Auth (ficticios)")
rows = []
for p in people:
    sub, email, _ = LOGIN_USERS.get(p["name"], (f"demo-{p['id'][:8]}", f"demo-{p['id'][:8]}@demo.icexalumni.invalid", "socio"))
    p["sub"], p["email"] = sub, email
    meta = '{"name": %s, "sub": "%s", "custom_claims": {"icex_member_verified": true, "name": %s}}' % (
        '"' + p["name"] + '"', sub, '"' + p["name"] + '"')
    rows.append(f"({q(p['id'])}, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', {q(email)}, "
                f"'{{\"provider\": \"custom:icex-alumni\", \"providers\": [\"custom:icex-alumni\"]}}', {q(meta)}, "
                f"now() - interval '{random.randint(30, 400)} days', now(), now())")
w("insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, email_confirmed_at) values\n  "
  + ",\n  ".join(rows) + ";")

w("\n-- Identidades OIDC de los usuarios de prueba (login con el proveedor local custom:icex-alumni)")
for name, (sub, email, _) in LOGIN_USERS.items():
    p = by_name[name]
    w(f"insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at) values "
      f"({q(sub)}, {q(p['id'])}, '{{\"sub\": \"{sub}\", \"email\": \"{email}\", \"email_verified\": true, \"icex_member_verified\": true}}', "
      f"'custom:icex-alumni', now(), now(), now());")

w("\ninsert into identity.members (user_id, wp_subject, status, role, verified_at) values\n  " + ",\n  ".join(
    f"({q(p['id'])}, {q(p['sub'])}, 'active', '{LOGIN_USERS.get(p['name'], ('', '', 'socio'))[2]}', now() - interval '{random.randint(20, 300)} days')"
    for p in people) + ";")
# Dos moderadores ficticios
w(f"update identity.members set role = 'moderador' where user_id in ({q(by_name['Sergio Castro Ruiz']['id'])}, {q(by_name['Irene Blanco Rubio']['id'])});")

prow = []
for p in people:
    city, country, cc, lat, lng = CITY[p["ciudad"]]
    jitter = lambda: round(random.uniform(-0.04, 0.04), 2)
    sector = SECTOR_OF.get(p["empresa"], random.choice(list(set(SECTOR_OF.values()))))
    p["sector"] = sector
    bio = random.choice(BIOS).format(sector=sector.lower(), ciudad=city) if random.random() < 0.7 else None
    vis = '{"cargo":"socios","empresa":"socios","ciudad":"socios","ubicacion":"%s","bio":"socios","trayectoria":"socios"}' % (
        "socios" if random.random() < 0.9 else random.choice(["seguidores", "solo_yo"]))
    prow.append(
        f"({q(p['id'])}, {q(slug(p['name'], p['id']))}, {q(p['name'])}, {q(p['cargo'])}, {q(p['empresa'])}, '{p['fase']}', {p['promo']}, "
        f"{q(country)}, '{cc}', {q(city)}, {q(sector)}, "
        f"extensions.st_setsrid(extensions.st_makepoint({lng + jitter()}, {lat + jitter()}), 4326)::extensions.geography, "
        f"{q(bio)}, '{vis}'::jsonb, {str(random.random() < 0.92).lower()})")
w("\ninsert into profiles.profiles (user_id, slug, nombre, cargo, empresa, fase, promocion, pais, pais_code, ciudad, sector, ubicacion, bio, visibilidad, acepta_sugerencias) values\n  "
  + ",\n  ".join(prow) + ";")
w("insert into notifications.preferences (user_id) select user_id from identity.members on conflict do nothing;")

# Trayectoria
erows = []
for p in people:
    if p["fase"] in ("activo",) or random.random() < 0.3:
        year = 2026 - max(1, 51 - p["promo"])
        n = random.randint(1, 3)
        for i in range(n):
            desde = f"{min(2025, year + i * 2)}-{random.randint(1, 12):02d}-01"
            hasta = "null" if i == n - 1 else f"'{min(2026, year + i * 2 + 2)}-{random.randint(1, 12):02d}-01'"
            emp = p["empresa"] if i == n - 1 else random.choice(COMPANIES)
            cargo = p["cargo"] if i == n - 1 else random.choice(ROLES_ACTIVO)
            erows.append(f"({q(uid())}, {q(p['id'])}, {q(emp)}, {q(cargo)}, '{desde}', {hasta})")
w("\ninsert into profiles.experiences (id, user_id, empresa, cargo, desde, hasta) values\n  " + ",\n  ".join(erows)
  + "\non conflict do nothing;")
w("delete from profiles.experiences where hasta is not null and hasta < desde;")

# ----------------------------------------------------------------- social -----
frows = set()
ids = [p["id"] for p in people]
for p in people:
    k = 19 if p is ana else random.randint(3, 35)
    for t in random.sample(ids, k + 1):
        if t != p["id"]:
            frows.add((p["id"], t))
        if len([1 for f in frows if f[0] == p["id"]]) >= k:
            break
# Muchos siguen a los autores con nombre (más seguidores, como en el mockup)
for p in people[:30]:
    for s in random.sample(ids, random.randint(40, 160)):
        if s != p["id"]:
            frows.add((s, p["id"]))
w("\ninsert into social.follows (seguidor_id, seguido_id, created_at) values\n  " + ",\n  ".join(
    f"({q(a)}, {q(b)}, now() - interval '{random.randint(1, 300)} days')" for a, b in sorted(frows)) + ";")

# ----------------------------------------------------------------- clubs ------
CLUBS = ["Madrid", "Barcelona", "Nueva York", "Londres", "Berlín", "Bruselas", "Ciudad de México", "Singapur",
         "Shanghái", "São Paulo", "Dubái", "Lima", "París", "Tokio"]
club_ids = {}
crows = []
for cn in CLUBS:
    city, country, cc, lat, lng = CITY[cn]
    cid = uid()
    club_ids[cn] = cid
    crows.append(f"({q(cid)}, {q('Club Alumni ' + cn)}, {q(city)}, {q(country)}, '{cc}', "
                 f"extensions.st_setsrid(extensions.st_makepoint({lng}, {lat}), 4326)::extensions.geography, "
                 f"{q(f'Punto de encuentro de los alumni ICEX en {city}: cafés profesionales, bienvenida a quienes llegan y eventos con la Oficina Económica y Comercial.')})")
w("\ninsert into clubs.clubs (id, nombre, ciudad, pais, pais_code, ubicacion, descripcion) values\n  " + ",\n  ".join(crows) + ";")
cmrows = []
for p in people:
    if p["ciudad"] in club_ids and random.random() < 0.6:
        cmrows.append((club_ids[p["ciudad"]], p["id"]))
cmrows.append((club_ids["Lima"], ana["id"]))
cmrows.append((club_ids["Madrid"], ana["id"]))
cmrows = sorted(set(cmrows))
organizers = {}
for cid, u in cmrows:
    organizers.setdefault(cid, u)
w("insert into clubs.club_members (club_id, user_id, rol) values\n  " + ",\n  ".join(
    f"({q(c)}, {q(u)}, '{'organizador' if organizers[c] == u else 'miembro'}')" for c, u in cmrows) + ";")
w("update clubs.clubs c set miembros_count = (select count(*) from clubs.club_members m where m.club_id = c.id);")

EVENTS = [
    ("Madrid", "Café entre promociones: primeros pasos tras la beca", 4, "Sede ICEX, Paseo de la Castellana 278", 60),
    ("Barcelona", "Mesa de emprendimiento internacional", 9, "Barcelona Activa", 30),
    ("Nueva York", "Afterwork Club Alumni Nueva York con la OEC", 11, "Midtown, Manhattan", 40),
    ("Londres", "Networking de fin de año", 25, "Embajada de España, Londres", 80),
    ("Berlín", "Café de bienvenida a la 51ª promoción", 6, "Mitte, Berlín", 25),
    ("Ciudad de México", "Distribución B2B en México: casos reales", 14, "OEC Ciudad de México", 50),
    ("Singapur", "Asia en primera persona: adaptación y red", 19, "Online", None),
    ("Lima", "Encuentro de alumni en Perú", 12, "Miraflores, Lima", 35),
    ("Bruselas", "Contratación pública europea para alumni", 21, "Rue de la Loi, Bruselas", 30),
    ("Madrid", "Preparar la entrevista de Fase II", 16, "Online", 100),
]
erows2 = []
for cn, titulo, days, lugar, aforo in EVENTS:
    eid = uid()
    erows2.append(f"({q(eid)}, {q(club_ids[cn])}, {q(titulo)}, {q('Encuentro organizado por el ' + 'Club Alumni ' + cn + '. Plazas limitadas.')}, "
                  f"date_trunc('day', now()) + interval '{days} days 19 hours', date_trunc('day', now()) + interval '{days} days 21 hours', "
                  f"{q(lugar)}, {aforo if aforo else 'null'}, {q(organizers.get(club_ids[cn]))})")
w("\ninsert into clubs.events (id, club_id, titulo, descripcion, inicio, fin, lugar, aforo, created_by) values\n  " + ",\n  ".join(erows2) + ";")

# ------------------------------------------------------------------ feed -------
POSTS = [  # autor, tipo, minutos atrás, texto
    ("Javier Martín Jiménez", "general", 15, "¿Preparando tu llegada a Singapur? Después de un año aquí, estos son mis tres imprescindibles: comparar el trayecto al trabajo antes de elegir barrio, revisar las condiciones del alquiler por escrito y dejar margen para los primeros gastos. Si estás en Fase I y te mudas este trimestre, encantado de compartir mi checklist. 🇸🇬"),
    ("Sergio Castro Ruiz", "evento", 35, "Café entre promociones en Madrid ☕ En unos días nos reunimos para hablar de los primeros pasos después de la beca. Habrá mesas de energía, tecnología y consumo. Me gustaría contar también con compañeros de la 51ª: vuestras preguntas son el mejor punto de partida."),
    ("Inés Domínguez Gil", "oportunidad_laboral", 50, "Estoy preparando un equipo de desarrollo de negocio para proyectos de transición energética en Europa. Busco conversar con alumni con experiencia en análisis de mercado y relación con distribuidores. Inglés profesional y curiosidad por el sector. Si te interesa, escríbeme con la categoría Oportunidad laboral."),
    ("Jorge Álvarez Romero", "general", 60, "Una idea para quienes empiezan en una Oficina Comercial: llevad un diario de aprendizaje, no solo una lista de tareas.\n• ¿Qué pregunta hizo hoy una empresa?\n• ¿Qué fuente permitió responderla?\n• ¿Qué habría hecho de otra manera?\nAl final del mes tendréis vuestro primer mapa del mercado y material para aportar valor en Fase II."),
    ("Inés Castro Sáez", "logro", 120, "¡Primer contrato cerrado en Arabia Saudí! 🇸🇦 Tras 8 meses de trabajo hemos adjudicado el mantenimiento de la línea de metro de Riad. Gracias a los compañeros de la 44ª que me abrieron puertas en la Oficina Comercial. La red ICEX funciona."),
    ("Borja Sánchez Romero", "logro", 180, "La primera colaboración nacida de esta red ya está en marcha: tres compañeros de distintas promociones estamos trabajando en una propuesta de acceso a mercado para una pyme agroalimentaria. Lo mejor ha sido juntar experiencia comercial, logística y conocimiento local. Gracias a quienes nos presentasteis. 🤝"),
    ("María Martín García", "oportunidad_laboral", 240, "Buscamos Export Manager para mercados nórdicos en nuestra sede de Estocolmo. Perfil ideal: alumni ICEX, 3-5 años de experiencia, inglés nativo y valorable sueco. Escribidme por mensaje con la etiqueta 'Oportunidad laboral'."),
    ("Carlos Ortega Fernández", "general", 300, "Pregunta para la comunidad de México: ¿cómo organizáis la búsqueda de distribuidores cuando el producto necesita una explicación técnica? Estamos comparando venta directa, socio local y un modelo mixto. Me interesa especialmente qué señales os hicieron descartar un candidato, no solo cómo encontrasteis al elegido."),
    ("Blanca Navarro Castro", "evento", 360, "Club Alumni Nueva York: afterwork en Midtown, con la participación del Consejero Económico y Comercial. Plazas limitadas, confirmad en el club."),
    ("Elena Sáez Romero", "evento", 420, "Encuentro online entre alumni de Asia y compañeros que preparan su destino. Hablaremos de adaptación cultural, vida diaria y cómo construir una red desde cero. Estoy recogiendo preguntas para que la conversación sea práctica. ¿Qué os habría gustado saber antes de llegar?"),
    ("Miguel Echevarría Arrieta", "general", 540, "Reflexión tras 15 años en Asia: el mayor activo de un becario ICEX no es lo que aprende en la Oficina, sino la red que construye. Os comparto las 5 lecciones que me hubiera gustado saber en mi Fase I 👇\n1. Pregunta siempre por el contexto local.\n2. Aprende a decir que no.\n3. La paciencia es una ventaja competitiva.\n4. Documenta todo.\n5. Mantén el contacto con tu promoción."),
    ("Sara Navarro Hernández", "general", 1500, "Cambio de sector después de la beca: pasé de consumo a tecnología y lo más difícil fue explicar lo que sí era transferible. Negociación, análisis de mercados y coordinación internacional valen más de lo que pensamos. ¿Alguien está viviendo un cambio parecido? Me gustaría intercambiar experiencias."),
    ("Paula Álvarez Pérez", "oportunidad_laboral", 1560, "Buscamos un perfil junior de operaciones internacionales para un proyecto de expansión en Portugal. Valorable experiencia de Fase I o II, atención al detalle y ganas de aprender sobre logística y atención a clientes B2B. Compartiré el alcance y las condiciones por mensaje antes de cualquier candidatura."),
    ("Alejandro Iglesias Castro", "general", 1620, "Mi checklist antes de una feria internacional:\n1. Definir qué conversaciones merecen la pena.\n2. Preparar una propuesta en una frase.\n3. Reservar huecos para reuniones imprevistas.\n4. Anotar el siguiente paso al terminar cada encuentro.\n5. Hacer seguimiento con contexto, no con un correo genérico.\n¿Qué añadiríais desde vuestra experiencia?"),
    ("Diego Arrieta Marín", "logro", 1680, "¡Cinco años desde mi Fase I! Hoy he vuelto a hablar con la persona que me acompañó al llegar y hemos recordado aquella primera semana de dudas. Si estás empezando: pedir ayuda no te hace menos profesional. Si ya eres alumni: un mensaje de bienvenida puede cambiar mucho. ❤️"),
    ("Carlos Martín Delgado", "general", 2900, "Para los alumni que vivís en Bruselas: estoy buscando compañeros con experiencia en contratación pública europea para contrastar una estrategia de entrada. No necesito una solución cerrada; me vendría genial entender qué preguntas hacer antes de invertir tiempo en la primera licitación."),
    ("Rocío Pérez Gómez", "evento", 2950, "El club de Barcelona prepara una mesa pequeña sobre emprendimiento internacional. Queremos compartir decisiones difíciles: elegir mercado, encontrar socios y financiar el primer año. Si has emprendido o estás explorándolo, me encantará conocer tu experiencia."),
    ("Álvaro Sánchez Moreno", "general", 3000, "Una recomendación para las entrevistas de Fase II: sustituye «hice estudios de mercado» por un ejemplo concreto. Qué decisión había que tomar, qué analizaste y cómo se utilizó tu trabajo. No hace falta adornarlo: el contexto y el criterio cuentan más que una lista larga de funciones."),
    ("Lucía Castro Hernández", "oportunidad_laboral", 4400, "Proyecto de consultoría en internacionalización: buscamos colaboración puntual de alumni con experiencia en canales de distribución en Marruecos. Queremos revisar hipótesis antes de lanzar el trabajo de campo. Si conoces el mercado, hablemos del alcance, dedicación y remuneración."),
    ("Irene Blanco Rubio", "general", 4450, "Recién llegada a Berlín y buscando conversaciones, no solo contactos. ¿Hay alumni del sector salud o tecnología con ganas de un café este mes? También agradezco consejos para encontrar comunidad y espacios de trabajo. Prometo devolver el favor a los próximos que lleguen. 🇩🇪"),
    ("Sergio Iglesias Martínez", "logro", 5800, "Cerramos la primera ronda de mentoría con una conclusión compartida: escuchar antes de aconsejar. Hemos hablado de destinos, entrevistas y dudas de carrera, pero cada conversación ha sido distinta. Gracias a quienes habéis dedicado tiempo y a los becarios que habéis compartido vuestras preguntas."),
    ("Marta Serrano Marín", "general", 5850, "Hilo abierto para la 51ª promoción: ¿qué os gustaría preguntar a quienes ya han pasado por todas las fases? Empiezo con algo que me habría ayudado: no existe un único camino después de ICEX. Empresa, instituciones, emprendimiento o especialización pueden ser buenos siguientes pasos."),
    ("Carmen Rubio Marín", "logro", 5900, "Tras tres años en Londres, mi equipo ha abierto distribución en cinco nuevos mercados europeos. Gracias a la red por cada presentación y cada consejo sincero. Si estás valorando el sector de bebidas, escríbeme: encantada de contarte lo que funcionó y lo que no."),
    ("Gonzalo López Jiménez", "general", 7300, "Nigeria es uno de los mercados más dinámicos de África occidental y también uno de los que más preparación exige. Si estás valorando Lagos como destino, te recomiendo hablar antes con la Oficina Comercial y con alumni que ya hayan trabajado allí. Abro hilo para dudas."),
]
NEWS = [  # título, etiqueta, días atrás, fijado, texto
    ("Reunión Anual ICEX Alumni 2026: El networking en la comunidad de becarios", "Evento", 24, True,
     "El Prof. Dr. Gustavo E. Mata presentará el análisis estratégico sistémico de la asociación. Sede de ICEX en Madrid y en streaming."),
    ("Encuentros de noviembre: conversaciones entre promociones", "Clubs", 23, False,
     "Los clubs preparan cafés profesionales en Madrid y Barcelona y una sesión online entre destinos de Asia. Comparte tus preguntas con los organizadores a través de la categoría Evento."),
    ("La red comparte sus guías de llegada a nuevos destinos", "Recursos", 25, False,
     "Alumni de distintos mercados están recopilando experiencias sobre vivienda, adaptación cultural y primeros pasos profesionales. Son recomendaciones personales; contrasta siempre los trámites con fuentes oficiales."),
    ("Mentoría: nuevas conversaciones para la 51ª promoción", "Mentoría", 26, False,
     "La próxima ronda conectará a becarios con alumni de sectores y trayectorias diversas. El objetivo es resolver dudas concretas sobre destinos, entrevistas y desarrollo profesional."),
    ("Comparte oportunidades con información clara", "Empleo", 29, False,
     "Animamos a los miembros a acompañar sus ofertas con el alcance del puesto, ubicación, modalidad y proceso de selección. Las conversaciones de empleo pueden organizarse con la categoría Oportunidad laboral."),
    ("Historias de carrera: del primer destino al cambio de sector", "Trayectorias", 31, False,
     "La comunidad recoge experiencias de alumni que han cambiado de mercado, sector o tipo de organización. Las primeras conversaciones abordan tecnología, energía y emprendimiento."),
    ("Conectando generaciones: preguntas que abren conversaciones", "Comunidad", 35, False,
     "Los nuevos becarios comparten sus dudas con promociones anteriores. Invitamos a la red a aportar experiencias concretas y a mantener abiertas las conversaciones después de cada encuentro."),
    ("Clubs internacionales: bienvenida a quienes llegan", "Clubs", 37, False,
     "Los encuentros locales de este trimestre ponen el foco en quienes se trasladan a un nuevo país. Encontrar compañeros de destino es una forma de empezar a construir red desde la primera semana."),
    ("Colaboración entre alumni: experiencias para aprender juntos", "Colaboración", 41, False,
     "Abrimos un espacio editorial para compartir cómo nacen las colaboraciones profesionales entre promociones: primeras conversaciones, aprendizajes y decisiones que ayudaron a avanzar."),
    ("50 años de Becas ICEX: talento español para empresas globales", "Aniversario", 27, False,
     "Arranca el programa conmemorativo con actos en más de 30 ciudades. Consulta el calendario de tu club."),
    ("Bienvenida a la 51ª promoción", "Comunidad", 32, False,
     "Más de 240 nuevos becarios inician su Fase 0. Animamos a todos los alumni a seguirles y ofrecer mentoría."),
    ("Nuevo programa de mentoring Alumni-Becarios", "Programa", 39, False,
     "Abierta la convocatoria para mentores Activos. Dedicación: 2 horas al mes durante la Fase I."),
    ("Acuerdo con 12 nuevas empresas para prácticas de Fase II", "Empleo", 46, False,
     "Se amplía la red de empresas colaboradoras en energía, defensa y agroalimentación."),
]
COMMENTS = ["¡Muy útil, gracias por compartirlo!", "Me lo guardo para mi Fase I.", "Totalmente de acuerdo.",
            "¿Podemos hablarlo por mensaje? Estoy en una situación parecida.", "Gran iniciativa 👏",
            "Añadiría: preguntar siempre por el siguiente paso.", "Cuenta conmigo.", "Enhorabuena, merecidísimo.",
            "Yo pasé por lo mismo en mi destino. Te escribo.", "Gracias por abrir este hilo."]

post_rows, post_ids = [], []
for autor, tipo, mins, texto in POSTS:
    pid = uid()
    post_ids.append(pid)
    post_rows.append(f"({q(pid)}, {q(by_name[autor]['id'])}, '{tipo}', null, null, {q(texto)}, false, now() - interval '{mins} minutes')")
# Publicaciones de relleno de socios aleatorios (para paginación y feed de seguidos)
FILLER = ["Hoy he cerrado mi primera reunión con un distribuidor local. Pequeños pasos 🙌",
          "¿Alguien en {ciudad} con experiencia en licitaciones públicas? Agradecería un café.",
          "Comparto un aprendizaje de esta semana: escuchar al cliente antes de presentar el producto cambia la conversación.",
          "Buscamos perfiles con experiencia en {sector} para un proyecto en {ciudad}. Escribidme por mensaje.",
          "Gracias a la red por las presentaciones de este mes. Seguimos construyendo comunidad desde {ciudad}."]
for i in range(140):
    p = random.choice(people)
    pid = uid()
    post_ids.append(pid)
    tipo = random.choices(["general", "oportunidad_laboral", "logro", "evento"], weights=[6, 2, 2, 1])[0]
    texto = random.choice(FILLER).format(ciudad=p["ciudad"], sector=p["sector"].lower())
    post_rows.append(f"({q(pid)}, {q(p['id'])}, '{tipo}', null, null, {q(texto)}, false, now() - interval '{random.randint(60 * 24 * 4, 60 * 24 * 120)} minutes')")
for titulo, etiqueta, dias, fijado, texto in NEWS:
    pid = uid()
    post_rows.append(f"({q(pid)}, {q(laura['id'])}, 'novedad_oficial', {q(titulo)}, {q(etiqueta)}, {q(texto)}, {str(fijado).lower()}, now() - interval '{dias} days')")
w("\ninsert into feed.posts (id, autor_id, tipo, titulo, etiqueta, texto, fijado, created_at) values\n  " + ",\n  ".join(post_rows) + ";")

rec_rows, com_rows = [], []
for idx, pid in enumerate(post_ids):
    n = random.randint(40, 260) if idx < len(POSTS) else random.randint(0, 25)
    for u in random.sample(ids, n):
        rec_rows.append(f"({q(pid)}, {q(u)})")
    for _ in range(random.randint(2, 8) if idx < len(POSTS) else random.randint(0, 2)):
        com_rows.append(f"({q(uid())}, {q(pid)}, {q(random.choice(ids))}, {q(random.choice(COMMENTS))}, now() - interval '{random.randint(1, 600)} minutes')")
w("\ninsert into feed.recommendations (post_id, user_id) values\n  " + ",\n  ".join(rec_rows) + "\non conflict do nothing;")
w("\ninsert into feed.comments (id, post_id, autor_id, texto, created_at) values\n  " + ",\n  ".join(com_rows) + ";")
w("""update feed.comments c set created_at = p.created_at + interval '5 minutes'
  from feed.posts p where p.id = c.post_id and c.created_at < p.created_at;""")

# Contadores desnormalizados (los triggers estaban desactivados durante la carga)
w("""
update feed.posts p set
  recomendaciones_count = (select count(*) from feed.recommendations r where r.post_id = p.id),
  comentarios_count = (select count(*) from feed.comments c where c.post_id = p.id);
update profiles.profiles pr set
  seguidores_count = (select count(*) from social.follows f where f.seguido_id = pr.user_id),
  siguiendo_count = (select count(*) from social.follows f where f.seguidor_id = pr.user_id),
  posts_count = (select count(*) from feed.posts p where p.autor_id = pr.user_id);""")

# ------------------------------------------------------------- mensajería -----
CONVS = [  # otro, categoría, no_leidos de Ana, mensajes [(de_ana?, texto)]
    ("Javier Martín Jiménez", "solicitud_informacion", 1, [
        (True, "Hola Javier, vi tu publicación sobre Singapur. Me planteo pedir ese destino en la próxima convocatoria."),
        (False, "¡Hola Ana! Encantado de ayudarte. ¿Te interesa más la instalación o conocer el entorno profesional?")]),
    ("Sergio Castro Ruiz", "evento", 1, [
        (True, "¿Vais a contar con la 51ª en el café de Madrid?"),
        (False, "Sí, queremos partir de sus dudas. Te paso el resumen cuando cerremos las mesas.")]),
    ("Borja Sánchez Romero", "colaboracion_empresarial", 0, [
        (False, "¿Cómo veis la entrada de la pyme por distribuidor o con socio local?"),
        (True, "Estamos comparando dos opciones. Primero validaremos distribuidores y costes logísticos.")]),
    ("Sara Navarro Hernández", "networking", 0, [
        (True, "¿Cómo preparaste el cambio de sector?"),
        (False, "Claro. A mí me ayudó preparar tres ejemplos de negociación y decisiones de mercado. Podemos comentarlos esta semana.")]),
    ("Jorge Álvarez Romero", "mentoria", 1, [
        (False, "¿Podrías ayudarme a convertir un estudio de mercado en un ejemplo para la entrevista?")]),
    ("Miguel Gómez Romero", "networking", 0, [
        (True, "¿Has decidido ya el siguiente paso?"),
        (False, "Voy a hablar con compañeros de dos sectores antes de decidir mis siguientes pasos.")]),
    ("María Martín García", "oportunidad_laboral", 2, [
        (True, "Hola María, me interesa la posición de Estocolmo."),
        (False, "¡Genial! Te cuento el proceso: dos entrevistas y un caso práctico."),
        (False, "¿Te vendría bien una llamada esta semana?")]),
    ("Carmen Rubio Marín", "mentoria", 0, [
        (True, "Muchas gracias por la sesión de ayer, me ha aclarado mucho."),
        (False, "¡Un placer! Cualquier cosa me escribes.")]),
    ("Gonzalo López Jiménez", "solicitud_informacion", 1, [
        (False, "¿Tienes contactos en la Oficina Comercial de Lagos para una licitación?")]),
    ("Blanca Navarro Castro", "evento", 0, [
        (False, "¿Te apunto al afterwork del club?"),
        (True, "¡Genial, apuntado!")]),
]
w("\n-- Conversaciones de demostración (Ana)")
minutes = 20
for other, cat, unread, msgs in CONVS:
    o = by_name[other]
    cid = uid()
    a, b = sorted([ana["id"], o["id"]])
    w(f"insert into messaging.conversations (id, tipo, categoria, direct_key, creado_por, created_at) values "
      f"({q(cid)}, 'directa', '{cat}', '{a}:{b}', {q(ana['id'])}, now() - interval '{minutes + 600} minutes');")
    w(f"insert into messaging.conversation_members (conversation_id, user_id, no_leidos) values ({q(cid)}, {q(ana['id'])}, {unread}), ({q(cid)}, {q(o['id'])}, 0);")
    for j, (from_ana, texto) in enumerate(msgs):
        t = minutes + (len(msgs) - j) * 7
        w(f"insert into messaging.messages (id, conversation_id, remitente_id, cuerpo, created_at) values "
          f"(util.uuid_v7(now() - interval '{t} minutes'), {q(cid)}, {q(ana['id'] if from_ana else o['id'])}, {q(texto)}, now() - interval '{t} minutes');")
    w(f"""update messaging.conversations c set ultimo_mensaje_id = m.id, ultimo_mensaje_en = m.created_at, ultimo_mensaje_preview = left(m.cuerpo, 140)
  from (select * from messaging.messages where conversation_id = {q(cid)} order by id desc limit 1) m where c.id = {q(cid)};""")
    w(f"""update messaging.conversation_members cm set ultimo_leido_id = (
  select id from messaging.messages m where m.conversation_id = cm.conversation_id
  order by id desc offset case when cm.user_id = {q(ana['id'])} then {unread} else 0 end limit 1)
  where cm.conversation_id = {q(cid)};""")
    minutes += random.randint(30, 400)

# Notificaciones de ejemplo para Ana
w(f"""
insert into notifications.notifications (user_id, tipo, group_key, actor_ids, total, payload, leido, created_at, updated_at)
select {q(ana['id'])}, 'nuevo_seguidor', 'follow', array_agg(f.seguidor_id order by f.created_at desc), count(*), '{{}}'::jsonb, false, now() - interval '2 hours', now() - interval '2 hours'
  from (select * from social.follows where seguido_id = {q(ana['id'])} order by created_at desc limit 5) f;
insert into notifications.notifications (user_id, tipo, actor_ids, payload, leido, created_at, updated_at)
select {q(ana['id'])}, 'novedad', array[{q(laura['id'])}::uuid], jsonb_build_object('post_id', p.id, 'titulo', p.titulo), true, p.created_at, p.created_at
  from feed.posts p where p.tipo = 'novedad_oficial' order by p.created_at desc limit 3;""")

w("\ncommit;")
w("set session_replication_role = origin;")
w("\n-- Cola de indexado del Orientador (el indexador la procesa por cron)")
w("select pgmq.send('embeddings', jsonb_build_object('source_tipo', 'post', 'source_id', id)) from feed.posts where not oculto and visibilidad = 'socios';")
w("select pgmq.send('embeddings', jsonb_build_object('source_tipo', 'perfil', 'source_id', user_id)) from profiles.profiles where acepta_sugerencias;")
w("analyze identity.members, profiles.profiles, profiles.experiences, social.follows, feed.posts, feed.comments, feed.recommendations, clubs.clubs, clubs.club_members, clubs.events, messaging.conversations, messaging.conversation_members, messaging.messages, notifications.notifications;")
print("\n".join(out))
