# Beta abierta (preproducción)

Esta versión es para que pruebe mucha gente: **cualquiera crea una cuenta con correo y contraseña**, sin ser
socio de ICEX Alumni. El acceso de socios por la web de la asociación (OIDC) sigue en el código y volverá en la
siguiente versión. Para eso solo hay que cambiar `ACCESS_MODE` y `AUTH_MODE`.

La beta inicial es **solo Android** y funciona **entera en planes gratuitos**. El único servicio de pago es
Mailrelay, que ICEX Alumni ya tiene.

## Calendario (objetivo: cerrada antes de fin de año)

| Fechas | Quién | Qué | Para pasar a lo siguiente |
|---|---|---|---|
| **jue 26 – dom 29 nov** · Preparación | Equipo | Pasos 1–6 de abajo: Supabase (dos proyectos gratuitos), SMTP de Mailrelay, política de privacidad, firma de Android y Firebase. *Deploy backend → staging* y *Release beta*. Instalarla en un móvil propio. | La prueba de humo sale en verde y alguien del equipo se registra de principio a fin con el correo real. |
| **lun 30 nov – vie 4 dic** · Ronda 1 (v0.1.0) | 5–6 personas de confianza | Usar la app a diario, en móviles y versiones de Android distintos: instalación, registro, correo de confirmación, perfil, publicaciones, seguir y mensajes. Los fallos van al formulario (*Ajustes → Enviar comentarios*). Revisamos los fallos 15 min al día. | No queda ningún fallo que bloquee el registro, la entrada o los mensajes. |
| **lun 7 – vie 11 dic** (puente) · Ronda 2 (v0.1.1) | Los mismos 5–6 + simulación | La versión con los arreglos; repiten la prueba. Cada fallo de la ronda 1 queda cubierto por un test automático. **Mié 9: prueba de carga** (sin personas, ver abajo). | Sin fallos graves nuevos y con el informe de carga: sabemos cuántos usuarios simultáneos aguanta. |
| **lun 14 – vie 18 dic** · Ronda 3 | 30–50 personas | Beta ampliada con el enlace de invitación de Firebase. **Jue 17, 13:00: «hora punta» real**: 15–20 personas usan la app a la vez durante 15 minutos (escribirse, publicar, recomendar). Medimos el consumo en el panel de Supabase. | El consumo está por debajo de la mitad de los límites gratuitos y la hora punta no da errores. |
| **lun 21 – mié 23 dic** · Cierre (v0.2.0) | Equipo | Última versión con los arreglos de la ronda 3. Informe final: fallos encontrados y resueltos, resultados de carga y consumo. Decisión sobre Supabase Pro y sobre la siguiente versión (acceso de socios). | **Beta cerrada y documentada.** |
| **24 dic – 6 ene** · Congelado | — | Sin versiones nuevas. La app sigue abierta para quien la use y *Keepalive* evita que el proyecto se pause. | — |

## Cómo encaja

```
Probadores (Android) → Firebase App Distribution (APK firmado)
        │  app compilada con AUTH_MODE=password contra el proyecto de staging
        ▼
Supabase «icex-atlas-staging» (UE, plan gratuito)
  Auth: email + contraseña, confirmación por correo (SMTP de Mailrelay), hooks de las migraciones
  Postgres: migraciones del repo + config 'access.mode' = open_beta
  Edge Functions: orientador, push, borrado de cuenta… (las seis del repo)
        ▲
GitHub Actions
  «Deploy backend» (staging | carga): db push → functions deploy → configure_supabase.py → smoke_test.py
  «Release beta»: APK → Firebase App Distribution
  «Keepalive Supabase»: lunes y jueves, para que el plan gratuito no se pause
  «Load test»: prueba de carga contra «icex-atlas-carga» (otro proyecto gratuito)
```

Cómo funciona la cuenta beta:
- **Alta y datos.** Al registrarse se crea un socio de origen `beta`. Usa la app entera, con las mismas reglas de
  privacidad, bloqueo, borrado de cuenta y exportación de datos.
- **Promoción.** Puede indicar su promoción si es alumni. Si no, no aparece ninguna.
- **Final de la beta.** Se cierra el registro con `ACCESS_MODE=alumni`. Las cuentas beta siguen entrando hasta que
  se decida qué hacer con ellas (`identity.members.origen = 'beta'`).

## Coste

| Servicio | Para qué | Coste |
|---|---|---|
| Supabase (plan gratuito) | Backend de la beta y, aparte, el proyecto de la prueba de carga (se permiten 2 activos) | 0 € |
| Mailrelay | Correos de confirmación y de contraseña por SMTP | Ya contratado por ICEX Alumni |
| Firebase App Distribution | Repartir el APK a los probadores | 0 € |
| GitHub Actions | Despliegues, builds, keepalive y carga | 0 € (minutos gratuitos) |

**Límites del plan gratuito de Supabase que importan aquí:** 50.000 usuarios activos al mes, 500 MB de base de
datos, 1 GB de ficheros (fotos), 5 GB de tráfico, 500.000 invocaciones de funciones y **200 conexiones simultáneas
de tiempo real** (cada móvil con la app abierta usa una). Además:
- **Pausa por inactividad.** El proyecto se pausa tras 7 días sin actividad; lo evita el flujo *Keepalive*. Si aun
  así se pausa, *Keepalive* sale en rojo, GitHub avisa por correo y se reactiva en el panel (*Restore project*).
- **Sin copias de seguridad.** Si se pierde la base de datos, se pierden los datos de los probadores. Es aceptable
  en una beta. Si deja de serlo, se pasa a Pro.

**Cuándo pasar a Pro (25 $/mes):** cuando la prueba de carga o la hora punta muestren que 200 conexiones de tiempo
real se quedan cortas, cuando el consumo pase de la mitad de algún límite, cuando no podáis permitiros perder datos
o antes de abrirla a socios. Es un clic en el panel y no hay que volver a desplegar.

## Dónde publicar la beta

1. **Firebase App Distribution (la elegida).** Es lo más fácil y gratis.
   - Invitas por correo o con un enlace.
   - El probador abre el enlace, instala la app y recibe un aviso con cada versión nueva.
   - No hay revisión de tienda: subes un APK y en minutos está disponible.
   - Tiene un inconveniente: el probador debe permitir «instalar apps de origen desconocido». Firebase lo explica
     paso a paso en la invitación.
2. **Google Play, más adelante.** Solo si queréis que se instale sin «origen desconocido». La *prueba interna*
   (hasta 100 personas, sin revisión) cuesta 25 $ una vez. Si la cuenta de desarrollador es **personal** y nueva,
   para salir a producción exigen 14 días de prueba cerrada con al menos 12 probadores; como **organización**
   (con D-U-N-S) no.
3. **iPhone, más adelante.** Todo está preparado para TestFlight (ver el final). Necesita la cuenta de
   desarrollador de Apple (99 $/año).
4. **Comentarios de los probadores.** Crea un formulario (Google Forms o Tally) con: qué hacías, qué esperabas, qué
   pasó, modelo de móvil y captura. Pon su URL en `FEEDBACK_URL`: aparece en *Ajustes → Enviar comentarios de la
   beta*.

## Puesta en marcha, paso a paso (≈ 1 h la primera vez)

### 1. Supabase (dos proyectos gratuitos)
1. En supabase.com, crea la organización (plan **Free**) y el proyecto `icex-atlas-staging` en región **UE
   (Frankfurt)**. Apunta la **contraseña de la base de datos** que eliges.
2. Copia el **Project ref**: es lo que va entre `https://` y `.supabase.co`.
3. Crea un **access token** en *Account → Access Tokens*.
4. Crea un segundo proyecto, `icex-atlas-carga`, también en Frankfurt. Es solo para la prueba de carga: así la
   beta no se ensucia ni se satura. Apunta su ref y su contraseña.

### 2. Correo (SMTP de Mailrelay)
1. En el panel de Mailrelay, entra en la configuración **SMTP** y apunta el servidor, el puerto (587), el usuario y
   la contraseña SMTP. El envío transaccional por SMTP va incluido en los planes de pago.
2. Usa un remitente del dominio de la asociación, p. ej. `no-responder@icex-alumni.com`. Comprueba en Mailrelay que
   ese dominio tiene **SPF y DKIM** verificados; si no, los correos de confirmación acabarán en spam.
3. Haz una prueba con un correo de Gmail y otro de Outlook antes de la ronda 1.

### 3. Política de privacidad
Publica una política de privacidad en una URL pública. Hay un borrador en `docs/legal/politica-privacidad-beta.md`
que **debe revisar quien lleve el RGPD en la asociación**. La URL va en la variable `PRIVACY_URL`. Se enlaza en
el registro y en Ajustes.

### 4. GitHub → Settings → Environments
Crea dos entornos, **sin revisores obligatorios** (el *Keepalive* programado no podría esperar una aprobación).

**`staging`, secretos** (*Environment secrets*):

| Nombre | Valor |
|---|---|
| `SUPABASE_ACCESS_TOKEN` | token del paso 1.3 |
| `SUPABASE_PROJECT_REF` | ref de `icex-atlas-staging` |
| `SUPABASE_DB_PASSWORD` | su contraseña de la base de datos |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_SENDER_EMAIL` | paso 2 |
| `LLM_PROVIDER`, `LLM_API_KEY`, `LLM_MODEL`, `LLM_BASE_URL` | *opcional*: Orientador con IA real. Sin ellos responde con plantillas |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | `./scripts/release/android-keystore.sh` (una sola vez; **guarda el .jks**: sin él los probadores no podrán actualizar) |
| `FIREBASE_ANDROID_APP_ID`, `FIREBASE_SERVICE_ACCOUNT_JSON` | paso 5 |
| `GOOGLE_SERVICES_JSON_BASE64` | *opcional*: notificaciones push (Firebase Cloud Messaging) |
| `PUSH_PROVIDER=fcm`, `FCM_SERVICE_ACCOUNT_JSON` | *opcional*: push desde el backend |
| `SENTRY_DSN` | *opcional*: informes de fallos |

**`staging`, variables** (*Environment variables*, no son secretas):

| Nombre | Valor |
|---|---|
| `ACCESS_MODE` | `open_beta` (es el valor por defecto en staging) |
| `FEEDBACK_URL` | formulario de comentarios |
| `PRIVACY_URL` | política de privacidad |
| `FIREBASE_TESTER_GROUPS` | alias del grupo en App Distribution (por defecto `beta`) |
| `SMTP_SENDER_NAME` | nombre del remitente (por defecto «ICEX Atlas») |
| `EMAIL_RATE_LIMIT_PER_HOUR` | correos de Auth por hora (por defecto 100) |

**`carga`, secretos:** `SUPABASE_ACCESS_TOKEN`, y `SUPABASE_PROJECT_REF` y `SUPABASE_DB_PASSWORD` de
`icex-atlas-carga`. Nada más: este proyecto no envía correos.

La URL y la clave pública de Supabase **no** hay que copiarlas: los flujos las leen del proyecto con el token.

### 5. Firebase App Distribution
1. Crea un proyecto en console.firebase.google.com y añade una app Android con el paquete `es.icexalumni.atlas`.
2. Copia el **App ID** (`1:…:android:…`) en `FIREBASE_ANDROID_APP_ID`.
3. En *App Distribution*, crea el grupo de probadores con alias `beta` y añade los correos de la ronda 1. Para la
   ronda 3, activa el **enlace de invitación**.
4. En *Google Cloud → IAM*, crea una cuenta de servicio con el rol **Firebase App Distribution Admin**. Descarga su
   clave JSON y pégala entera en `FIREBASE_SERVICE_ACCOUNT_JSON`.
5. *Opcional*: para notificaciones push, descarga `google-services.json` y guárdalo en base64 en
   `GOOGLE_SERVICES_JSON_BASE64` (`base64 -i google-services.json | pbcopy`).

### 6. Desplegar y publicar
1. *Actions → Deploy backend → Run workflow → staging*. Aplica las migraciones y las funciones y configura Auth (con
   correos en español), la API, Vault y el modo beta. Termina con una **prueba de humo**: crea una cuenta, entra,
   lee el feed, publica, comprueba los permisos y borra lo creado. Si algo falla, el flujo sale en rojo y dice qué.
2. Repite con **carga** (mismo flujo, entorno `carga`).
3. *Actions → Release beta → Run workflow* con las notas de la versión. Compila el APK firmado y lo envía a
   Firebase; los probadores reciben un correo. El APK queda también como artefacto de la ejecución.
4. *Actions → Keepalive Supabase → Run workflow* una vez, para comprobar que funciona.

Para cada versión nueva: fusiona en la rama, lanza *Deploy backend → staging* si hay migraciones o funciones nuevas
y después *Release beta*.

## Prueba de carga (mié 9 dic)

*Actions → Load test → Run workflow.* Se lanza contra `icex-atlas-carga`, nunca contra la beta: el script exige que
el ref confirmado sea el del entorno `carga`.

Qué hace (`scripts/load/carga.py`):
1. Crea tantas cuentas como el escalón más alto, sin enviar correos. Inicia sesión con cada una y crea un grafo
   social: 8 seguimientos y un post por cuenta, más algunas conversaciones.
2. Sube por escalones de usuarios **a la vez**. Cada usuario virtual abre su conexión de tiempo real como la app y
   repite lo que hace una persona, con pausas de 3 a 8 s: leer el feed, mirar no leídos, buscar, ver perfiles,
   recomendar, seguir, publicar y escribirse.
3. Mide, por escalón: peticiones por segundo, tiempos de respuesta (p50, p95 y p99) y errores por operación.
   También cuántos consiguen conexión de tiempo real y cuánto tarda en llegar el aviso de un mensaje nuevo.
4. Borra todo lo creado y deja el informe en el resumen de la ejecución y como artefacto.

Ejecuciones previstas:

| Ejecución | Escalones | Tiempo real | Para qué |
|---|---|---|---|
| 1 | `50,200,500,1000` | `1` (todos con la app abierta) | El peor caso. Lo esperado es que el tiempo real se corte en 200: es el límite del plan gratuito |
| 2 | `50,200,500,1000` | `0.3` | Lo realista: solo una parte tiene la app en primer plano. Muestra el límite de la API y la base de datos |
| 3 | `200` durante `600` s | `1` | Resistencia: 10 minutos seguidos con el máximo del plan gratuito |

Cómo leer el informe:
- **Aguanta hasta N usuarios**: es el último escalón con menos del 1 % de errores, p95 por debajo de 800 ms y todos
  con tiempo real.
- Si lo primero que falla es el **tiempo real**, el límite son las conexiones simultáneas (200 gratis, 500 en Pro).
- Si sube el **p95** y aparecen errores `HTTP 5xx` o `timeout`, el límite es la CPU o las conexiones de la base de
  datos de la instancia.

Si una prueba se interrumpe y quedan cuentas, relánzala marcando **limpiar**.

En local, con escalones pequeños, porque los límites de Auth de desarrollo admiten unos 25 inicios de sesión cada
5 min:
```bash
pip install "aiohttp>=3.10,<4"
source scripts/lib/supabase-env.sh
SUPABASE_URL=$API_URL SUPABASE_ANON_KEY=$ANON_KEY SUPABASE_SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY \
  CARGA_CONFIRMAR=local ESCALONES=10,25 SEGUNDOS_ESCALON=40 python3 scripts/load/carga.py
```

## Probarlo en local antes de subir
```bash
AUTH_MODE=password ./scripts/start-local.sh    # portada beta con «Crear cuenta» / «Ya tengo cuenta»
# Prueba de humo contra el Supabase local:
source scripts/lib/supabase-env.sh
SUPABASE_URL=$API_URL SUPABASE_ANON_KEY=$ANON_KEY SUPABASE_SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY \
  python3 scripts/deploy/smoke_test.py
```
En local no se pide confirmar el correo. En la nube sí: el enlace del correo abre la app.

## iPhone (TestFlight), cuando toque
Está todo preparado (`release-beta.yml`, job `ios`, y `app/fastlane`), pero apagado. Para activarlo:
1. Alta en el Apple Developer Program (99 $/año) y la app `es.icexalumni.atlas` en App Store Connect.
2. Clave de la API de App Store Connect (rol *App Manager*) en los secretos `APP_STORE_CONNECT_API_KEY_ID`,
   `APP_STORE_CONNECT_API_ISSUER_ID` y `APP_STORE_CONNECT_API_KEY_CONTENT` (el `.p8` en base64), más
   `APPLE_TEAM_ID`.
3. Un repositorio privado vacío para los certificados de `match` (`MATCH_GIT_URL`). Desde un Mac, ejecutar una vez
   `cd app && bundle exec fastlane match appstore` y guardar `MATCH_PASSWORD`.
4. Opcional: push en iPhone con `GOOGLE_SERVICE_INFO_PLIST_BASE64`.
5. En TestFlight, un grupo **externo** «Beta» con **enlace público** y la *Test information* completa (incluida una
   cuenta de prueba para el revisor). Su nombre va en la variable `TESTFLIGHT_GROUPS`, y el correo de comentarios en
   `BETA_FEEDBACK_EMAIL`.
6. Variable **de repositorio** (no de entorno) `IOS_BETA_ENABLED=true`, y en *Release beta* elegir `ios` o `both`.

## Qué queda fuera de esta beta
- **Captcha en el registro.** Supabase admite Turnstile o hCaptcha, pero la app tendría que enviar el token. Si
  hubiera altas automáticas masivas: activar captcha y bajar `rate_limit` de registros.
- **Vincular la cuenta beta con la de socio**, en la siguiente versión. Con OIDC, el email de la cuenta beta y el
  de la web de la asociación pueden coincidir. Habrá que decidir si se fusionan.
- **Panel de administración web.** Sigue el procedimiento de `docs/runbook.md` si se quiere moderar desde el
  navegador.
