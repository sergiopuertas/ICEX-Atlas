#!/usr/bin/env python3
"""Comunidad de demostración para grabar la demo de ICEX Atlas.

Crea ~40 personas FICTICIAS (nombres, empresas y textos inventados) con perfiles completos,
trayectoria, ubicación en el mapa, clubs, publicaciones de varios tipos con recomendaciones y
comentarios, novedades oficiales y conversaciones. Además, tres cuentas para grabar:

  · nueva  — Lucía: recién registrada, perfil vacío, no sigue a nadie (arranque en frío).
  · marina — Marina: perfil completo, con conversaciones y un mensaje sin leer.
  · javier — Javier: el segundo móvil, para el chat en tiempo real con Marina.

Va contra un proyecto de PRUEBAS (p. ej. «icex-atlas-carga»), nunca contra el de la beta: hay
que confirmar el ref en DEMO_CONFIRMAR. Las cuentas son @demo.icexatlas.invalid y se borran con
--borrar. Todas las acciones pasan por la API (las funciones api.*) como lo haría la app, salvo
las fechas, que se reparten en los últimos días para que el feed parezca vivo.

Uso (nube):
  SUPABASE_ACCESS_TOKEN=… SUPABASE_PROJECT_REF=abcd DEMO_CONFIRMAR=abcd [DEMO_PASSWORD=…] \\
    python3 scripts/demo/seed_demo.py            # crea (si ya existe, la rehace)
    python3 scripts/demo/seed_demo.py --borrar   # borra todo lo de la demo
Uso (local): SUPABASE_URL=… SUPABASE_ANON_KEY=… SUPABASE_SERVICE_ROLE_KEY=… DEMO_CONFIRMAR=local …
(en local necesita `pip install "psycopg[binary]"`).
"""

from __future__ import annotations

import json
import os
import random
import secrets
import sys
import time
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "deploy"))
from supa import Project, lit, opt, request  # noqa: E402

DOMAIN = "demo.icexatlas.invalid"
rng = random.Random(2026)  # misma comunidad en cada ejecución

CITIES = {  # ciudad: (país, código, lat, lng)
    "Madrid": ("España", "ES", 40.4168, -3.7038), "Barcelona": ("España", "ES", 41.3874, 2.1686),
    "Valencia": ("España", "ES", 39.4699, -0.3763), "Sevilla": ("España", "ES", 37.3891, -5.9845),
    "Bilbao": ("España", "ES", 43.2630, -2.9350), "Ciudad de México": ("México", "MX", 19.4326, -99.1332),
    "Lima": ("Perú", "PE", -12.0464, -77.0428), "Bogotá": ("Colombia", "CO", 4.7110, -74.0721),
    "Santiago": ("Chile", "CL", -33.4489, -70.6693), "Buenos Aires": ("Argentina", "AR", -34.6037, -58.3816),
    "São Paulo": ("Brasil", "BR", -23.5505, -46.6333), "Nueva York": ("Estados Unidos", "US", 40.7128, -74.0060),
    "Miami": ("Estados Unidos", "US", 25.7617, -80.1918), "Toronto": ("Canadá", "CA", 43.6532, -79.3832),
    "Londres": ("Reino Unido", "GB", 51.5072, -0.1276), "París": ("Francia", "FR", 48.8566, 2.3522),
    "Berlín": ("Alemania", "DE", 52.5200, 13.4050), "Milán": ("Italia", "IT", 45.4642, 9.1900),
    "Varsovia": ("Polonia", "PL", 52.2297, 21.0122), "Casablanca": ("Marruecos", "MA", 33.5731, -7.5898),
    "Johannesburgo": ("Sudáfrica", "ZA", -26.2041, 28.0473), "Dubái": ("Emiratos Árabes Unidos", "AE", 25.2048, 55.2708),
    "Shanghái": ("China", "CN", 31.2304, 121.4737), "Singapur": ("Singapur", "SG", 1.3521, 103.8198),
    "Tokio": ("Japón", "JP", 35.6762, 139.6503), "Seúl": ("Corea del Sur", "KR", 37.5665, 126.9780),
    "Sídney": ("Australia", "AU", -33.8688, 151.2093), "Bombay": ("India", "IN", 19.0760, 72.8777),
}

# (clave, nombre, promoción, fase, cargo, empresa, ciudad, sector). Empresas inventadas.
PEOPLE = [
    ("marina", "Marina Soler Vidal", 49, "activo", "Export Manager LATAM", "Valverde Renovables", "Ciudad de México", "Energía"),
    ("javier", "Javier Molina Ruiz", 51, "fase_0", None, None, "Madrid", "Tecnología"),
    ("carmen", "Carmen Iglesias Prat", 45, "activo", "Directora de Desarrollo Internacional", "Bodegas Altozano", "Londres", "Vino"),
    ("pablo", "Pablo Ferrer Lozano", 50, "fase_2", "Becario ICEX", "Oficina Económica y Comercial de España en Shanghái", "Shanghái", "Industria"),
    ("ines", "Inés Domínguez Gil", 47, "activo", "Country Manager", "Navalia Tech", "Singapur", "Tecnología"),
    ("david", "David Rubio Santos", 42, "activo", "Socio", "Tramontana Consultores", "Madrid", "Consultoría"),
    ("laura", "Laura Gil Navarro", 48, "activo", "Responsable de Licitaciones", "Mediterránea de Infraestructuras", "Lima", "Infraestructuras"),
    ("sergio", "Sergio Campos Ortiz", 50, "fase_1", "Becario ICEX", "Oficina Económica y Comercial de España en Dubái", "Dubái", "Energía"),
    ("elena", "Elena Vázquez Moreno", 39, "activo", "Head of Business Development", "Kora Robotics", "Berlín", "Industria"),
    ("alvaro", "Álvaro Peña Castillo", 46, "activo", "Key Account Manager", "Olivares del Sur", "Nueva York", "Agroalimentario"),
    ("lucia_m", "Lucía Martín Herrera", 51, "fase_0", None, None, "Valencia", "Agroalimentario"),
    ("jorge", "Jorge Navarro Blanco", 44, "activo", "Director Comercial", "Logística Atlántica", "Miami", "Logística"),
    ("paula", "Paula Ramos Serrano", 50, "fase_2", "Becaria ICEX", "Oficina Económica y Comercial de España en Bogotá", "Bogotá", "Salud"),
    ("hector", "Héctor Sanz Medina", 43, "activo", "Director General", "Cerámicas del Turia", "Casablanca", "Industria"),
    ("nuria", "Nuria Castro Delgado", 47, "activo", "Brand Manager", "Hispania Moda", "Milán", "Moda"),
    ("ruben", "Rubén Ortega Prieto", 49, "activo", "Analista de Mercados", "Nubia Software", "Toronto", "Tecnología"),
    ("teresa", "Teresa Morales Vega", 36, "activo", "Consejera Delegada", "Grupo Tramontana", "Madrid", "Finanzas"),
    ("adrian", "Adrián León Fuentes", 50, "fase_1", "Becario ICEX", "Oficina Económica y Comercial de España en Tokio", "Tokio", "Tecnología"),
    ("cristina", "Cristina Pascual Ibáñez", 48, "activo", "Gerente de Exportación", "Aerotécnica Norte", "París", "Industria"),
    ("marcos", "Marcos Herrero Soto", 45, "activo", "Director de Operaciones", "Valverde Renovables", "Santiago", "Energía"),
    ("sara", "Sara Cabrera Nieto", 49, "activo", "Trade Marketing Manager", "Olivares del Sur", "Shanghái", "Agroalimentario"),
    ("ivan", "Iván Reyes Calvo", 47, "activo", "Project Manager", "Mediterránea de Infraestructuras", "Dubái", "Infraestructuras"),
    ("beatriz", "Beatriz Lorenzo Marín", 41, "activo", "Directora de Expansión", "Nubia Software", "São Paulo", "Tecnología"),
    ("diego", "Diego Garrido Rey", 50, "fase_2", "Becario ICEX", "Oficina Económica y Comercial de España en Johannesburgo", "Johannesburgo", "Energía"),
    ("alba", "Alba Santana Romero", 46, "activo", "Responsable de Alianzas", "Kora Robotics", "Seúl", "Industria"),
    ("victor", "Víctor Durán Esteban", 40, "activo", "Director de Compras", "Hispania Moda", "Bombay", "Moda"),
    ("silvia", "Silvia Moreno Arias", 48, "activo", "Consultora Senior", "Tramontana Consultores", "Buenos Aires", "Consultoría"),
    ("raul", "Raúl Gallego Pardo", 44, "activo", "Export Area Manager", "Bodegas Altozano", "Varsovia", "Vino"),
    ("irene", "Irene Bravo Cano", 50, "fase_1", "Becaria ICEX", "Oficina Económica y Comercial de España en Sídney", "Sídney", "Turismo"),
    ("oscar", "Óscar Vidal Mora", 38, "activo", "Fundador", "Logística Atlántica", "Barcelona", "Logística"),
    ("marta", "Marta Ruiz Peña", 47, "activo", "Directora Financiera", "Cerámicas del Turia", "Sevilla", "Finanzas"),
    ("andres", "Andrés Crespo Vera", 49, "activo", "Business Developer", "Navalia Tech", "Bilbao", "Tecnología"),
    ("lorena", "Lorena Méndez Gómez", 51, "fase_0", None, None, "Barcelona", "Moda"),
    ("tomas", "Tomás Aguilar Rojas", 43, "activo", "Director de Planta", "Aerotécnica Norte", "Ciudad de México", "Industria"),
    ("noelia", "Noelia Fuentes Ruiz", 46, "activo", "Category Manager", "Olivares del Sur", "Londres", "Agroalimentario"),
    ("gonzalo", "Gonzalo Benítez Lara", 50, "fase_2", "Becario ICEX", "Oficina Económica y Comercial de España en Lima", "Lima", "Infraestructuras"),
    ("equipo", "Equipo ICEX Alumni", 1, "activo", "Junta Directiva", "ICEX Alumni", "Madrid", "Asociación"),
    ("nueva", "Lucía Herrero Campos", 0, "activo", None, None, None, None),
]

BIOS = [
    "Llevo {anos} años abriendo mercados para empresas españolas. Encantada de ayudar a quien empieza su destino.",
    "Me interesan la internacionalización de pymes y la financiación multilateral. Siempre dispuesto a tomar un café virtual.",
    "Después de la beca me quedé en {ciudad}. Si vienes por aquí, escríbeme y te presento a la comunidad local.",
    "Apasionada del comercio exterior y del trabajo en equipo. Mentora en el programa de la asociación.",
    "Del {sector_l} a todo el mundo. Busco perfiles con ganas de aprender y abiertos a cambiar de país.",
]

POSTS = [
    ("general", "Primer mes en {ciudad}: lo que más me ha ayudado ha sido la red de alumni de aquí. Gracias a todos los que me escribisteis antes de llegar."),
    ("oportunidad_laboral", "Buscamos Export Area Manager para {region} en {empresa}. Valoramos experiencia en {sector_l} y movilidad. Escribidme por mensaje y os cuento."),
    ("evento", "El jueves organizamos un encuentro de alumni en {ciudad}, a partir de las 19:30. Si estás de paso, apúntate en los comentarios."),
    ("logro", "Hoy cerramos nuestro primer contrato en {pais}. Tres años de trabajo y muchas conversaciones con la Oficina Comercial. ¡Gracias a todo el equipo!"),
    ("general", "Consejo para la promoción {promo_siguiente}: preparad bien la Fase II y no dejéis el idioma para el final. Cualquier duda, por aquí."),
    ("general", "He preparado una guía sobre cómo acceder a licitaciones públicas en {pais}. Si os interesa, la comparto con quien la pida."),
    ("oportunidad_laboral", "Prácticas de seis meses en {empresa} ({ciudad}) para perfiles recién salidos de la beca. Inicio en febrero."),
    ("general", "¿Alguien de la red con experiencia en certificaciones para exportar {sector_l} a {pais}? Agradecería un par de consejos."),
    ("evento", "Webinar abierto: «Cómo negociar con distribuidores en {region}». Lo damos tres alumni el día 12 a las 17:00, hora de Madrid."),
    ("logro", "Cinco años desde que empecé la beca en {ciudad}. Hoy asumo la dirección de {empresa} en la región. Esta red tiene mucho que ver."),
    ("general", "Comparto un aprendizaje de esta semana: en {pais} las relaciones van antes que el contrato. Paciencia y muchos cafés."),
    ("general", "Feria sectorial en {ciudad} la semana que viene. ¿Quién más va? Podemos coordinar visitas a estands."),
]
COMMENTS = [
    "¡Enhorabuena! Muy merecido.", "Me apunto, ¿hay que llevar algo?", "Te escribo por privado.",
    "Qué buena noticia, a por más.", "Gracias por compartirlo, muy útil.", "¿Podrías pasarme la guía? Me vendría genial.",
    "Yo voy el martes y el miércoles, hablamos.", "Muy de acuerdo, me pasó lo mismo en mi destino.",
    "Lo comparto con mi equipo.", "¡Qué recuerdos de esa etapa!", "Contad conmigo para el webinar.",
]
REGIONS = {"ES": "España", "MX": "Centroamérica", "PE": "la región andina", "CO": "la región andina", "CL": "el Cono Sur",
           "AR": "el Cono Sur", "BR": "Brasil", "US": "Norteamérica", "CA": "Norteamérica", "GB": "Europa",
           "FR": "Europa", "DE": "Europa Central", "IT": "Europa", "PL": "Europa del Este", "MA": "el Magreb",
           "ZA": "África Subsahariana", "AE": "Oriente Medio", "CN": "Asia-Pacífico", "SG": "el Sudeste Asiático",
           "JP": "Asia-Pacífico", "KR": "Asia-Pacífico", "AU": "Oceanía", "IN": "el Sur de Asia"}
CLUBS = ["Madrid", "Ciudad de México", "Londres", "Shanghái", "Nueva York", "Dubái", "Lima", "Singapur"]


def uuid7() -> str:
    ms = time.time_ns() // 1_000_000
    rand = int.from_bytes(os.urandom(10), "big")
    v = (ms << 80) | (0x7 << 76) | (((rand >> 62) & 0xFFF) << 64) | (0b10 << 62) | (rand & ((1 << 62) - 1))
    return str(uuid.UUID(int=v))


def sql_val(v) -> str:
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, list):
        return "array[" + ",".join(sql_val(x) for x in v) + "]::text[]"
    return lit(str(v))


def call(fn: str, **kw) -> str:
    args = ", ".join(f"{k} => {sql_val(v)}" for k, v in kw.items())
    return f"api.{fn}({args})"


class Script:
    """Acciones como cada usuario (rol authenticated + su uid), igual que la API de la app."""

    def __init__(self):
        self.lines: list[str] = []

    def as_user(self, uid: str, stmt: str):
        claims = json.dumps({"sub": uid, "role": "authenticated", "aud": "authenticated"})
        self.lines.append(f"select set_config('request.jwt.claims', {lit(claims)}, false);")
        self.lines.append("select set_config('role', 'authenticated', false);")
        self.lines.append(f"select {stmt};")
        self.lines.append("reset role;")

    def run(self, p: Project, label: str, chunk: int = 240):
        total = len(self.lines)
        for i in range(0, total, chunk):
            p.sql("\n".join(self.lines[i:i + chunk]) + "\nreset role;")
        print(f"  ✓ {label}")
        self.lines.clear()


def wipe(p: Project):
    like = lit(f"%@{DOMAIN}")
    p.sql(f"""
      delete from messaging.messages where remitente_id in (select id from auth.users where email like {like});
      delete from clubs.clubs where nombre like 'Club ICEX Alumni %' and descripcion like '%(demo)%';
      delete from auth.users where email like {like};
      delete from messaging.conversations c
       where not exists (select 1 from messaging.conversation_members m where m.conversation_id = c.id);
    """)
    print("  ✓ comunidad de demostración borrada")


def main() -> int:
    p = Project()
    if opt("DEMO_CONFIRMAR") != p.ref:
        sys.exit(f"✗ Esto llena el proyecto de personas ficticias. Úsalo en un proyecto de pruebas y confírmalo con "
                 f"DEMO_CONFIRMAR={p.ref}.")
    print(f"→ Demo en {p.url}")
    wipe(p)
    if "--borrar" in sys.argv:
        return 0

    password = opt("DEMO_PASSWORD") or secrets.token_urlsafe(9)
    keys = p.keys()
    admin_h = {"apikey": keys["service_role"], "Authorization": f"Bearer {keys['service_role']}"}
    ids: dict[str, str] = {}
    for key, nombre, promo, *_ in PEOPLE:
        user = request("POST", f"{p.url}/auth/v1/admin/users", headers=admin_h, body={
            "email": f"{key.replace('_', '.')}@{DOMAIN}", "password": password, "email_confirm": True,
            "user_metadata": {"name": nombre, "promocion": str(promo)}})
        ids[key] = user["id"]
    print(f"  ✓ {len(ids)} cuentas")
    p.sql(f"update identity.members set role = 'admin' where user_id = {lit(ids['equipo'])};"
          f"update identity.members set origen = 'alumni' where user_id in "
          f"({', '.join(lit(v) for k, v in ids.items() if k != 'nueva')});")

    s = Script()
    others = [k for k, *_ in PEOPLE if k not in ("nueva",)]
    info = {k: (n, pr, f, c, e, ci, se) for k, n, pr, f, c, e, ci, se in PEOPLE}

    # Perfiles, trayectoria y ubicación (Lucía, la recién llegada, se queda con el perfil vacío).
    for k in others:
        nombre, promo, fase, cargo, empresa, ciudad, sector = info[k]
        pais, code, lat, lng = CITIES[ciudad]
        bio = rng.choice(BIOS).format(anos=max(2, 2026 - (1975 + promo)), ciudad=ciudad, sector_l=sector.lower())
        s.as_user(ids[k], call("update_my_profile", p_cargo=cargo, p_empresa=empresa, p_fase=fase, p_pais=pais,
                               p_pais_code=code, p_ciudad=ciudad, p_sector=sector, p_bio=bio, p_lat=lat, p_lng=lng))
        if k == "equipo":
            continue
        year = 1975 + promo
        beca_city = ciudad if fase != "activo" else rng.choice([c for c in CITIES if CITIES[c][1] != "ES"])
        s.as_user(ids[k], call("upsert_experience", p_id=uuid7(), p_empresa=f"ICEX · OFECOME {beca_city}",
                               p_cargo="Becario/a de internacionalización", p_desde=f"{year}-01-15",
                               p_hasta=None if fase != "activo" else f"{year + 2}-01-14"))
        if fase == "activo" and empresa:
            s.as_user(ids[k], call("upsert_experience", p_id=uuid7(), p_empresa=empresa, p_cargo=cargo,
                                   p_desde=f"{min(2025, year + 2 + rng.randint(0, 4))}-03-01"))
    s.run(p, "perfiles, trayectoria y mapa")

    # Clubs (los crea el equipo) y socios de cada club.
    clubs: dict[str, str] = {}
    for c in CLUBS:
        pais, code, lat, lng = CITIES[c]
        clubs[c] = uuid7()
        s.as_user(ids["equipo"], call("admin_upsert_club", p_id=clubs[c], p_nombre=f"Club ICEX Alumni {c}", p_ciudad=c,
                                      p_pais=pais, p_lat=lat, p_lng=lng, p_pais_code=code,
                                      p_descripcion=f"Encuentros y contactos de la red en {c}. (demo)"))
    for k in others:
        ciudad = info[k][5]
        code = CITIES[ciudad][1]
        for c, cid in clubs.items():
            if CITIES[c][1] == code and k != "equipo":
                s.as_user(ids[k], call("join_club", p_club=cid))
    s.run(p, f"{len(clubs)} clubs")

    # Seguimientos: todos se siguen un poco; Marina es muy seguida; nadie sigue a Lucía.
    for k in others:
        if k == "equipo":
            continue
        pool = [x for x in others if x != k]
        targets = set(rng.sample(pool, rng.randint(6, 12))) | {"equipo"}
        if rng.random() < 0.7:
            targets.add("marina")
        targets.discard(k)
        for t in sorted(targets):
            s.as_user(ids[k], call("follow", p_user=ids[t]))
    s.run(p, "seguimientos")

    # Publicaciones, novedades, recomendaciones y comentarios.
    posts: list[tuple[str, str]] = []
    authors = [k for k in others if k not in ("equipo", "javier")]
    for i in range(46):
        k = authors[i % len(authors)] if i < len(authors) else rng.choice(authors)
        nombre, promo, fase, cargo, empresa, ciudad, sector = info[k]
        pais, code, *_ = CITIES[ciudad]
        tipo, tpl = rng.choice(POSTS if empresa else [x for x in POSTS if "{empresa}" not in x[1]])
        texto = tpl.format(ciudad=ciudad, pais=pais, empresa=empresa or "", sector_l=sector.lower(),
                           region=REGIONS.get(code, pais), promo_siguiente=f"{max(promo, 50) + 1}ª")
        pid = uuid7()
        posts.append((pid, k))
        s.as_user(ids[k], call("create_post", p_id=pid, p_texto=texto, p_tipo=tipo))
    news = [
        ("Encuentro Anual ICEX Alumni 2026", "Te esperamos el 12 de diciembre en Madrid y en streaming: balance del año, "
         "mesa redonda con alumni en cuatro continentes y networking. Inscripción abierta en Clubs → Madrid.", True, "Eventos"),
        ("Abrimos el programa de mentorías", "Si llevas más de cinco años de carrera internacional, puedes ser mentor o "
         "mentora de la 51ª promoción. Escríbenos por mensaje para apuntarte.", False, "Mentorías"),
    ]
    news_ids = []
    for titulo, texto, fijado, etiqueta in news:
        nid = uuid7()
        news_ids.append(nid)
        s.as_user(ids["equipo"], call("admin_publish_news", p_id=nid, p_titulo=titulo, p_texto=texto,
                                      p_etiqueta=etiqueta, p_fijado=fijado))
    for pid, autor in posts:
        fans = rng.sample([x for x in others if x != autor], rng.choice([0, 1, 2, 3, 5, 8, 12, 18, 25]))
        for f in fans:
            s.as_user(ids[f], call("recommend", p_post=pid))
        for _ in range(rng.choice([0, 0, 1, 1, 2, 3])):
            who = rng.choice([x for x in others if x not in (autor, "equipo")])
            s.as_user(ids[who], call("add_comment", p_id=uuid7(), p_post=pid, p_texto=rng.choice(COMMENTS)))
    s.run(p, f"{len(posts)} publicaciones, {len(news)} novedades, recomendaciones y comentarios")

    # Conversaciones de Marina (la de Javier termina con un mensaje sin leer para ella).
    chats = [
        ("javier", "mentoria", [
            ("javier", "Hola Marina, soy Javier, de la 51ª. En enero empiezo la Fase II en Ciudad de México. "
                       "¿Tendrías 20 minutos para contarme cómo es la Oficina?"),
            ("marina", "¡Hola, Javier! Claro que sí. Te cuento todo: vivienda, el equipo y cómo sacarle partido al primer mes."),
            ("javier", "¡Genial, muchas gracias! ¿Te viene bien el jueves a las 18:00 hora de Madrid?")]),
        ("carmen", "networking", [
            ("carmen", "Marina, ¿sigues en México? Estamos mirando distribuidores para el vino allí."),
            ("marina", "Sí, aquí sigo. Te paso un par de contactos de importadores de confianza esta semana.")]),
        ("jorge", "oportunidad_laboral", [
            ("jorge", "Vi tu publicación sobre la vacante. Tengo a alguien de mi equipo que encaja muy bien."),
            ("marina", "¡Perfecto! Pásale mi contacto y que me escriba por aquí.")]),
        ("ines", "colaboracion_empresarial", [
            ("ines", "¿Te animas a dar una charla en el club de Singapur sobre renovables en LATAM?"),
            ("marina", "Me encantaría. Mándame fechas y lo cuadramos.")]),
    ]
    for other, cat, msgs in chats:
        for n, (who, texto) in enumerate(msgs):
            to = ids[other] if who == "marina" else ids["marina"]
            if n == 0:
                s.as_user(ids[who], call("send_message", p_id=uuid7(), p_cuerpo=texto, p_to=to, p_categoria=cat))
            else:
                s.as_user(ids[who], f"api.send_message(p_id => {lit(uuid7())}, p_cuerpo => {lit(texto)}, p_to => {lit(to)})")
    s.run(p, f"{len(chats)} conversaciones")

    # Fechas: los últimos 9 días (la novedad fijada y un par de posts, de hoy).
    demo_users = ", ".join(lit(v) for v in ids.values())
    p.sql(f"""
      update feed.posts set created_at = now() - (random() * interval '9 days') - interval '3 hours',
                            updated_at = now()
       where autor_id in ({demo_users}) and tipo <> 'novedad_oficial'
         and id not in (select id from feed.posts where autor_id in ({demo_users}) order by id desc limit 3);
      update feed.posts set created_at = now() - interval '2 days' where id = {lit(news_ids[1])};
      update feed.comments c set created_at = p.created_at + (random() * (now() - p.created_at))
        from feed.posts p where p.id = c.post_id and c.autor_id in ({demo_users});
      select profiles.refresh_aggregates();
    """)
    print("  ✓ fechas repartidas y mapa actualizado")

    shown = "la de DEMO_PASSWORD" if opt("DEMO_PASSWORD") else password
    print(f"""
Listo. Cuentas para grabar (contraseña común: {shown}):
  · Lucía, recién llegada: nueva@{DOMAIN}
  · Marina, perfil completo: marina@{DOMAIN}
  · Javier, segundo móvil:   javier@{DOMAIN}
Guion: docs/demo.md""")
    return 0


if __name__ == "__main__":
    sys.exit(main())
