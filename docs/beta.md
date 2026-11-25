# Beta abierta (preproducción)

Esta versión es para que pruebe mucha gente: **cualquiera crea una cuenta con correo y contraseña**, sin ser
socio de ICEX Alumni. El acceso de socios por la web de la asociación (OIDC) sigue en el código y volverá en la
siguiente versión. Para eso solo hay que cambiar `ACCESS_MODE` y `AUTH_MODE`.

## Cómo encaja

```
Probadores
  Android → Firebase App Distribution (APK firmado)
  iPhone  → TestFlight (grupo externo, enlace público)
        │  app compilada con AUTH_MODE=password contra el proyecto de staging
        ▼
Supabase «icex-atlas-staging» (UE, plan Pro)
  Auth: email + contraseña, confirmación por correo (SMTP propio), hooks de las migraciones
  Postgres: migraciones del repo + config 'access.mode' = open_beta
  Edge Functions: orientador, push, borrado de cuenta… (las seis del repo)
        ▲
GitHub Actions
  «Deploy backend» (staging): db push → functions deploy → configure_supabase.py → smoke_test.py
  «Release beta»: APK → Firebase App Distribution · IPA → TestFlight
```

Cómo funciona la cuenta beta:
- **Alta y datos.** Al registrarse se crea un socio de origen `beta`. Usa la app entera, con las mismas reglas de
  privacidad, bloqueo, borrado de cuenta y exportación de datos.
- **Promoción.** Puede indicar su promoción si es alumni. Si no, no aparece ninguna.
- **Final de la beta.** Se cierra el registro con `ACCESS_MODE=alumni`. Las cuentas beta siguen entrando hasta que
  se decida qué hacer con ellas (`identity.members.origen = 'beta'`).

## Coste aproximado

| Servicio | Para qué | Coste |
|---|---|---|
| Supabase Pro | Backend. El plan gratuito pausa el proyecto tras 1 semana sin uso y no tiene copias diarias | 25 $/mes (incluye el primer proyecto) |
| SMTP (Resend, Brevo…) | Correos de confirmación y de contraseña. El de Supabase solo envía 2/hora y solo a tu equipo | 0 € en el plan gratuito |
| Firebase App Distribution | Repartir el APK de Android a los probadores | 0 € |
| Apple Developer Program | TestFlight para iPhone | 99 $/año |
| Google Play (opcional) | Prueba interna en Play, hasta 100 probadores | 25 $ una vez |

## Dónde publicar la beta: recomendaciones

1. **Android: Firebase App Distribution.** Es lo más fácil y gratis.
   - Invitas por correo o con un enlace.
   - El probador instala una app de Firebase (o abre la web) y recibe avisos de cada versión nueva.
   - No hay revisión de tienda: subes un APK y en minutos está disponible.
   - Tiene un inconveniente: el probador debe permitir «instalar apps de origen desconocido». Las instrucciones de
     Firebase lo explican paso a paso.
2. **iPhone: TestFlight.** Es la única vía razonable en iOS.
   - Exige la cuenta de desarrollador de Apple (99 $/año).
   - Crea un **grupo externo** con **enlace público**: admite hasta 10.000 probadores y no hace falta saber sus
     correos.
   - La primera versión pasa una revisión ligera de Apple (normalmente menos de 1 día). Las siguientes de la misma
     versión suelen ir directas.
   - Apple pide una descripción de la beta, un correo de contacto y **una cuenta de prueba para el revisor**. Crea
     una en la propia app y pégala en *Test information*.
3. **Google Play: solo si quieres que los Android la instalen sin «origen desconocido».**
   - La *prueba interna* (hasta 100 personas, sin revisión) cuesta 25 $ una vez.
   - Una cuenta de desarrollador **personal** nueva tiene un requisito para salir a producción más adelante: 14 días
     de prueba cerrada con al menos 12 probadores. Si la asociación abre la cuenta como **organización** (con
     D-U-N-S), no se aplica.
   - Para la beta, Firebase basta.
4. **Lo que no recomiendo para esta beta.**
   - Versión web: la app usa base de datos local, mapas y notificaciones móviles, y habría que adaptarla.
   - Enviar el APK por WhatsApp: no hay actualizaciones ni control de quién lo tiene.
5. **Comentarios de los probadores.** Crea un formulario (Google Forms o Tally) y pon su URL en `FEEDBACK_URL`.
   Aparecerá en *Ajustes → Enviar comentarios de la beta*. TestFlight y Firebase recogen además capturas y
   fallos.

## Puesta en marcha, paso a paso (≈ 1 h la primera vez)

### 1. Supabase
1. En supabase.com, crea la organización con plan **Pro** y el proyecto `icex-atlas-staging` en región **UE
   (Frankfurt)**. Apunta la **contraseña de la base de datos** que eliges.
2. Copia el **Project ref**: es lo que va entre `https://` y `.supabase.co`.
3. Crea un **access token** en *Account → Access Tokens*.

### 2. Correo (SMTP)
1. Crea una cuenta en un proveedor de SMTP. Resend y Brevo tienen plan gratuito y servidores en la UE.
2. Verifica un dominio de remitente (p. ej. `beta@icex-alumni.com`). Necesitas añadir registros DNS en el dominio.
3. Apunta host, puerto, usuario y contraseña SMTP.

### 3. Política de privacidad
Publica una política de privacidad en una URL pública. Hay un borrador en `docs/legal/politica-privacidad-beta.md`
que **debe revisar quien lleve el RGPD en la asociación**. La URL va en la variable `PRIVACY_URL`. Se enlaza en
el registro y en Ajustes, y la piden Apple y Google.

### 4. GitHub → Settings → Environments → `staging`
**Secretos** (*Environment secrets*):

| Nombre | Valor |
|---|---|
| `SUPABASE_ACCESS_TOKEN` | token del paso 1.3 |
| `SUPABASE_PROJECT_REF` | ref del paso 1.2 |
| `SUPABASE_DB_PASSWORD` | contraseña de la base de datos |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_SENDER_EMAIL` | paso 2 |
| `LLM_PROVIDER`, `LLM_API_KEY`, `LLM_MODEL`, `LLM_BASE_URL` | *opcional*: Orientador con IA real. Sin ellos responde con plantillas |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | `./scripts/release/android-keystore.sh` (una sola vez; **guarda el .jks**) |
| `FIREBASE_ANDROID_APP_ID`, `FIREBASE_SERVICE_ACCOUNT_JSON` | paso 5 |
| `GOOGLE_SERVICES_JSON_BASE64`, `GOOGLE_SERVICE_INFO_PLIST_BASE64` | *opcional*: notificaciones push (Firebase Cloud Messaging) |
| `PUSH_PROVIDER=fcm`, `FCM_SERVICE_ACCOUNT_JSON` | *opcional*: push desde el backend |
| `APPLE_TEAM_ID`, `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_CONTENT`, `MATCH_GIT_URL`, `MATCH_PASSWORD` | paso 6 (iOS) |
| `SENTRY_DSN` | *opcional*: informes de fallos |

**Variables** (*Environment variables*, no son secretas):

| Nombre | Valor |
|---|---|
| `ACCESS_MODE` | `open_beta` (es el valor por defecto en staging) |
| `FEEDBACK_URL` | formulario de comentarios |
| `PRIVACY_URL` | política de privacidad |
| `FIREBASE_TESTER_GROUPS` | alias del grupo en App Distribution (por defecto `beta`) |
| `TESTFLIGHT_GROUPS` | nombre del grupo externo de TestFlight (p. ej. `Beta`) |
| `BETA_FEEDBACK_EMAIL` | correo para los comentarios de TestFlight |
| `EMAIL_RATE_LIMIT_PER_HOUR` | correos de Auth por hora (por defecto 100) |

La URL y la clave pública de Supabase **no** hay que copiarlas: los flujos las leen del proyecto con el token.

### 5. Firebase App Distribution (Android)
1. Crea un proyecto en console.firebase.google.com y añade una app Android con el paquete `es.icexalumni.atlas`.
2. Copia el **App ID** (`1:…:android:…`) en `FIREBASE_ANDROID_APP_ID`.
3. En *App Distribution*, crea el grupo de probadores con alias `beta`. Puedes añadir correos o activar un
   **enlace de invitación**.
4. En *Google Cloud → IAM*, crea una cuenta de servicio con el rol **Firebase App Distribution Admin**. Descarga su
   clave JSON y pégala entera en `FIREBASE_SERVICE_ACCOUNT_JSON`.
5. *Opcional*: si quieres notificaciones push, descarga `google-services.json` y guárdalo en base64 en
   `GOOGLE_SERVICES_JSON_BASE64` (`base64 -i google-services.json | pbcopy`).

### 6. TestFlight (iPhone, opcional)
1. Date de alta en el Apple Developer Program y crea la app `es.icexalumni.atlas` en App Store Connect.
2. Crea una clave de la API de App Store Connect (rol *App Manager*). Rellena con ella `APP_STORE_CONNECT_API_*`;
   el `.p8` va en base64.
3. Crea un repositorio privado vacío para los certificados de `match`. Desde tu Mac, ejecuta una vez
   `cd app && bundle exec fastlane match appstore`. Te pedirá `MATCH_PASSWORD`, que luego guardas como secreto.
4. En TestFlight, crea un grupo **externo** «Beta», activa el **enlace público** y rellena *Test information*: la
   descripción, el correo y la cuenta de prueba para el revisor.

### 7. Desplegar y publicar
1. *Actions → Deploy backend → Run workflow → staging*. Aplica las migraciones y las funciones y configura Auth (con
   correos en español), la API, Vault y el modo beta. Termina con una **prueba de humo**: crea una cuenta, entra,
   lee el feed, publica, comprueba los permisos y borra lo creado. Si algo falla, el flujo sale en rojo y dice qué.
2. *Actions → Release beta → Run workflow*, eligiendo la plataforma y las notas de la versión.
   - **Android**: compila el APK firmado y lo envía a Firebase. Los probadores reciben un correo. El APK también
     queda como artefacto de la ejecución.
   - **iOS**: sube a TestFlight y, si `TESTFLIGHT_GROUPS` está definido, lo reparte al grupo externo.
3. Comparte los enlaces: la invitación de Firebase (Android) y el enlace público de TestFlight (iPhone).

Para cada versión nueva: fusiona en la rama, lanza *Deploy backend* si hay migraciones o funciones nuevas y
después *Release beta*.

### Probarlo en local antes de subir
```bash
AUTH_MODE=password ./scripts/start-local.sh    # portada beta con «Crear cuenta» / «Ya tengo cuenta»
# Prueba de humo contra el Supabase local:
source scripts/lib/supabase-env.sh
SUPABASE_URL=$API_URL SUPABASE_ANON_KEY=$ANON_KEY SUPABASE_SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY \
  python3 scripts/deploy/smoke_test.py
```
En local no se pide confirmar el correo. En la nube sí: el enlace del correo abre la app.

## Qué queda fuera de esta beta
- **Captcha en el registro.** Supabase admite Turnstile o hCaptcha, pero la app tendría que enviar el token. Si
  hubiera altas automáticas masivas: activar captcha y bajar `rate_limit` de registros.
- **Vincular la cuenta beta con la de socio**, en la siguiente versión. Con OIDC, el email de la cuenta beta y el
  de la web de la asociación pueden coincidir. Habrá que decidir si se fusionan.
- **Panel de administración web.** Sigue el procedimiento de `docs/runbook.md` si se quiere moderar desde el
  navegador.
