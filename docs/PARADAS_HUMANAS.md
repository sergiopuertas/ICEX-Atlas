# Paradas humanas

Pasos que **solo puede hacer una persona de ICEX Alumni**: crear cuentas, contratar, firmar, introducir credenciales
o tocar WordPress. Todo el código, la configuración y los scripts que los rodean ya están en el repositorio.
Sigue el orden. Cada paso indica qué desbloquea. Los valores obtenidos se guardan **solo** en gestores de secretos
(GitHub Environments, `supabase secrets`, gestor de contraseñas de la asociación), nunca en el repositorio.
La lista de variables está en `.env.example`.

Leyenda: ☐ pendiente · Responsable sugerido entre corchetes.

---

## 0. Beta abierta (preproducción): lo mínimo para empezar

Guía completa y calendario en `docs/beta.md`. Beta inicial: **solo Android y todo en planes gratuitos**.
☐ Proyecto gratuito de Supabase `icex-atlas-staging` (UE) + access token. Otro gratuito `icex-atlas-carga` para la prueba de carga.
☐ SMTP de Mailrelay (cuenta de pago de ICEX Alumni) con el dominio remitente verificado (SPF y DKIM).
☐ Política de privacidad publicada (borrador: `docs/legal/politica-privacidad-beta.md`, revisar con RGPD).
☐ Clave de firma Android (`scripts/release/android-keystore.sh`) + Firebase App Distribution.
☐ Secretos y variables de los entornos `staging` y `carga` en GitHub → *Deploy backend* → *Release beta*.
☐ (Más adelante) iPhone: Apple Developer Program + TestFlight; se activa con `IOS_BETA_ENABLED=true`.

## A. Decisiones previas (sin coste)

☐ **A1. Validar si aplica el ENS** (Esquema Nacional de Seguridad, RD 311/2022) [junta + asesoría]
   ICEX Alumni es una asociación privada. El ENS obliga a entidades del sector público y a quienes les prestan
   servicios. Hay que confirmar si existe convenio o encargo de tratamiento con ICEX España Exportación e Inversiones
   (entidad pública) que lo haga aplicable.
   - Si **no** aplica: anótalo en el registro de actividades de tratamiento y sigue.
   - Si **sí** aplica (categoría básica probable): se necesita declaración de conformidad. Supabase y los demás
     proveedores tendrán que acreditar certificaciones equivalentes (ISO 27001 / SOC 2) y habrá que documentar las
     medidas. Esto puede condicionar B1 y E1/E2, así que **decídelo antes de contratar**.

☐ **A2. RGPD: base jurídica y documentación** [delegado/a de protección de datos o asesoría]
   - Registro de actividades de tratamiento: red social de socios, mensajería, orientador con IA y notificaciones.
   - Actualizar la política de privacidad y las condiciones de uso de la app. La app enlaza a la web de la asociación
     (`ASSOCIATION_WEB_URL`), y las tiendas exigen una URL pública de privacidad.
   - Valorar una EIPD (evaluación de impacto). Hay geolocalización por ciudad, perfiles profesionales y uso de IA.
     Probablemente no sea obligatoria, pero conviene dejar constancia de la valoración.

## B. Supabase (backend)

☐ **B1. Crear la organización y los proyectos** [responsable técnico]
   1. Crea una cuenta en supabase.com con el email corporativo de la asociación y activa 2FA.
   2. Crea la organización «ICEX Alumni» con plan **Pro**.
   3. En *Billing*, **desactiva el Spend Cap**. Con el tope activado, al superar la cuota incluida (p. ej. conexiones
      Realtime o egress) el servicio se degrada en lugar de facturar el exceso. Con 1.000 → 5.000 socios (D-001),
      Pro sin tope basta (500 conexiones Realtime concurrentes incluidas, ampliables). **Team no es necesario**
      salvo que se requiera SSO al panel de Supabase o SOC 2 bajo NDA para A1.
   4. Crea **dos proyectos**: `icex-atlas-staging` y `icex-atlas-prod`.
      - **Región: `eu-west-3` (París)**. Elige esa región concreta en el desplegable, **nunca la opción genérica
        «Europe»**, que puede asignar cualquier región. Es la de menor latencia desde España.
        Alternativa válida: `eu-central-1` (Fráncfort).
      - Genera la contraseña de la base de datos con el gestor de contraseñas y guárdala ahí.
      - Postgres 17 (lo trae por defecto).
   5. Anota de cada proyecto: *Project ref*, URL, clave publishable/anon y clave secret/service_role.
   6. En producción, *Authentication → Providers → Email* debe quedar **desactivado**: solo se entra con WordPress.
      Durante la beta, staging lo tiene activado (lo hace `configure_supabase.py` con `ACCESS_MODE=open_beta`). En
      local está activo para el acceso rápido de desarrollo (`docs/autenticacion.md`).
   → Desbloquea: despliegue (runbook §1).

☐ **B2. Activar PITR en producción** [responsable técnico]
   Proyecto prod → *Database → Backups → Point in Time Recovery* → activar (add-on de pago, 7 días es suficiente).
   Requiere la instancia de cómputo mínima que indique el panel (Small o superior).

☐ **B3. Firmar el DPA de Supabase** [presidencia o persona con poder de firma]
   Dashboard → *Organization → Legal Documents* → solicitar y firmar el **Data Processing Addendum**
   (incluye las cláusulas contractuales tipo para las transferencias). Guarda el PDF firmado con la documentación RGPD.

☐ **B4. Token para CI y entornos de GitHub** [responsable técnico]
   1. En supabase.com → *Account → Access Tokens*, crea un token `github-actions`.
   2. En GitHub → repositorio → *Settings → Environments*, crea `staging` y `production` (este último con *required reviewers*).
      En cada uno define: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF`, `SUPABASE_DB_PASSWORD`.
   → Desbloquea: flujo *Deploy backend*. Después sigue `runbook.md §1` (pasos 2-10).

## C. WordPress (proveedor de identidad)

☐ **C1. Preparar una copia de pruebas de la web** [proveedor web de la asociación]
   Debe ser una copia (*staging*) de la web de ICEX Alumni con HTTPS y dominio público (p. ej. `staging.icex-alumni.com`).
   **No instales nada en la web real** hasta validar el flujo completo en staging.

☐ **C2. Instalar el plugin y el snippet de claims en la copia de pruebas**
   Sigue `wordpress/README.md` paso a paso:
   1. Instala y activa el plugin **OpenID Connect Server** (Automattic).
   2. Genera las claves RSA y defínelas en `wp-config.php`.
   3. Registra el cliente en `OIDC_CLIENTS` con *redirect URI* `https://<project-ref-staging>.supabase.co/auth/v1/callback`.
      Genera el `client_secret` con el gestor de contraseñas.
   4. Copia `wordpress/oidc-claims.php` a `wp-content/mu-plugins/`. **Adapta** `icex_atlas_is_active_member()` a cómo
      la web marca hoy a los socios activos (rol, plugin de membresías o campo de usuario). Por defecto usa el rol
      `socio_icex_alumni`.
   5. Define `ICEX_ATLAS_SYNC_TOKEN` (32 caracteres o más, aleatorio) en `wp-config.php`.
   6. Ejecuta las pruebas `curl` del README (discovery, claims de un socio y de un no socio, endpoint de membresías).
   → Desbloquea: alta del proveedor OIDC (runbook §1.5) y los secretos `WP_BASE_URL` y `WP_SYNC_TOKEN`.

☐ **C3. Prueba de aceptación en staging** [responsable técnico + 2 socios voluntarios]
   Un socio activo entra y usa la app. Una cuenta no socia ve «acceso solo para socios». Al dar de baja a un socio
   de prueba en WordPress, pierde el acceso tras la sincronía nocturna (o tras ejecutar `membership-sync` a mano).

☐ **C4. Repetir C2 en la web real** [proveedor web], con un cliente OIDC y un token distintos para producción, en una ventana
   de mantenimiento y con copia de seguridad previa de WordPress.

## D. Notificaciones push (Firebase / APNs)

☐ **D1. Proyecto Firebase** [responsable técnico]
   1. En console.firebase.google.com, crea el proyecto `icex-atlas` y desactiva Google Analytics (no se usa).
   2. Añade la app Android con el paquete `es.icexalumni.atlas` → descarga `google-services.json`.
   3. Añade la app iOS con el bundle ID `es.icexalumni.atlas` → descarga `GoogleService-Info.plist`.
   4. Guárdalos en base64 como secretos de GitHub: `GOOGLE_SERVICES_JSON_BASE64` y `GOOGLE_SERVICE_INFO_PLIST_BASE64`.
      En local, cópialos a `app/android/app/` y `app/ios/Runner/` (están en `.gitignore`).
   5. *Project settings → Service accounts* → genera una clave privada → secreto de Edge Functions
      `FCM_SERVICE_ACCOUNT_JSON` (JSON en una línea) y `PUSH_PROVIDER=fcm`.
   Nota RGPD: FCM solo recibe el token del dispositivo y un aviso genérico. El texto de los mensajes **no** viaja en el push.

☐ **D2. APNs (requiere E1)**
   1. En developer.apple.com → *Keys*, crea una clave con **Apple Push Notifications service** y descarga el `.p8`
      (solo se puede descargar una vez).
   2. En Firebase → *Project settings → Cloud Messaging → Apple app configuration*, sube el `.p8` con su Key ID y el Team ID.
   3. El identificador `es.icexalumni.atlas` debe tener activada la capacidad *Push Notifications*.
      El repositorio ya incluye `Runner.entitlements`.

## E. Tiendas

☐ **E1. Apple Developer Program (organización)** [presidencia]
   Para darse de alta como organización hace falta **número D-U-N-S** de la asociación (gratuito, tarda días).
   Cuota anual de 99 USD. Después:
   1. Registra el App ID `es.icexalumni.atlas` (capacidades: Push Notifications, Associated Domains si hay deep links web).
   2. En App Store Connect, crea la app «ICEX Atlas».
   3. Crea una API Key de App Store Connect (rol *App Manager*) → secretos `APP_STORE_CONNECT_KEY_ID`,
      `APP_STORE_CONNECT_ISSUER_ID` y `APP_STORE_CONNECT_KEY_CONTENT`. Define también `APPLE_TEAM_ID`.
   4. Crea un repositorio Git **privado** para certificados de Fastlane match y ejecuta una sola vez, desde un Mac,
      `cd app && bundle exec fastlane match appstore`. Fija `MATCH_PASSWORD` y `MATCH_GIT_URL`.
   5. Rellena la ficha: privacidad (*App Privacy*: identificadores, contenido de usuario, ubicación aproximada;
      sin seguimiento), clasificación por edad, capturas y **cuenta de prueba para la revisión de Apple**
      (un socio de prueba en WordPress, porque la app es privada).

☐ **E2. Google Play Console (organización)** [presidencia]
   1. Crea la cuenta de desarrollador de organización (25 USD, verificación de identidad y D-U-N-S).
   2. Crea la app «ICEX Atlas» con el paquete `es.icexalumni.atlas`.
   3. Genera la clave de subida:
      `keytool -genkeypair -v -keystore upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000`.
      Pásala a base64 como `ANDROID_KEYSTORE_BASE64` y define `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` y
      `ANDROID_KEY_PASSWORD`. Activa **Play App Signing**.
   4. En Google Cloud, crea una cuenta de servicio con acceso a la Play Console (*Users and permissions* → *Release manager*)
      → `PLAY_JSON_KEY_BASE64`.
   5. La **primera** subida a Play debe hacerse a mano (el AAB de `fastlane android build`). Después, CI sube a la pista interna.
   6. Rellena la ficha: seguridad de los datos, acceso a la app con credenciales de prueba, clasificación de contenido y público objetivo (adultos).

☐ **E3. Publicar** [junta]
   CI deja los builds en TestFlight y en la pista interna. Pasar a producción en las tiendas es una acción manual en cada consola.

## F. Proveedores con tratamiento en la UE

☐ **F1. Proveedor de IA (Orientador)** [responsable técnico + DPD]
   Requisitos: procesamiento y retención en la UE, sin uso de los datos para entrenar, DPA firmado y API compatible con
   OpenAI o con Anthropic (`LLM_PROVIDER`). Opciones a valorar:
   - Mistral AI (Francia), API `openai-compatible`.
   - Azure OpenAI o Amazon Bedrock en región UE con *data zone* UE.
   - Anthropic a través de una nube con región UE.
   Contrata y firma el DPA. Después configura `LLM_PROVIDER`, `LLM_BASE_URL` (endpoint UE), `LLM_API_KEY` y `LLM_MODEL`
   con `supabase secrets set`. Los embeddings no salen de Supabase (`EMBEDDINGS_PROVIDER=supabase-gte-small`, D-014).
   Hasta entonces, `LLM_PROVIDER=mock` da respuestas deterministas.

☐ **F2. Proveedor de email transaccional** [responsable técnico + DPD]
   El MVP **no envía emails propios**: el acceso es por WordPress y los avisos son push o internos. Si se activa el
   email (avisos de mensajes no leídos), elige un proveedor con servidores y tratamiento en la UE (p. ej. Brevo,
   Mailjet o Amazon SES `eu-west-3`), firma el DPA, verifica el dominio (SPF, DKIM, DMARC) y rellena las variables
   `EMAIL_*` reservadas en `.env.example`.

☐ **F3. Teselas del mapa** [responsable técnico]
   Contrata un proveedor con SLA y servidores en la UE (MapTiler, Stadia Maps…). OpenStreetMap no permite este uso en
   producción. Configura `MAP_TILE_URL` y `MAP_TILE_ATTRIBUTION` (runbook §6).

☐ **F4. Sentry (opcional, recomendado)** [responsable técnico]
   Crea una organización en sentry.io con **región de datos UE** (*EU data region*, Fráncfort) y firma su DPA. Crea el
   proyecto Flutter y configura `SENTRY_DSN` en `app/env/production.json` y `SENTRY_AUTH_TOKEN` en CI. La app ya
   elimina datos personales antes de enviar (`sendDefaultPii = false` y depuración de rutas).

## G. Infraestructura auxiliar

☐ **G1. Repositorio GitHub** [responsable técnico]
   Sube el código a `sergiopuertas/ICEX-Atlas` (o a la organización de la asociación). Activa la *branch protection* de `main`
   (CI obligatoria, revisión) y *secret scanning*.
☐ **G2. Hosting del panel admin** [responsable técnico]
   Hosting estático en la UE para `admin/build/web` (subdominio `admin.<dominio>`). Añade su origen a `ADMIN_ALLOWED_ORIGINS`
   y a las *Redirect URLs* de Supabase. En WordPress, da de alta el mismo cliente OIDC con la URL de callback de Supabase
   (es la misma). Asigna el primer `admin` desde el SQL Editor, cuando esa persona ya haya entrado una vez en la app:
   `update identity.members set role = 'admin' where user_id = '<uuid>';`. Los siguientes se asignan desde el propio
   panel (`api.admin_set_member_role`).

---

**Orden mínimo para tener staging funcionando:** A1 → B1 → B3 → B4 → C1 → C2 → runbook §1 → C3.
**Para producción, además:** A2, B2, D1, D2, E1, E2, F1, F3, C4, E3.
