# Registro de decisiones (ADR ligero)

Formato: **D-NNN · Título** — contexto → decisión → consecuencias.

## D-001 · Escala 1.000 → 5.000 socios
Contexto: el prompt pedía dimensionar para 10.000 y diseñar para 100.000. El 16/11/2026 producto lo reduce para controlar coste.
Decisión: dimensionar para **1.000** socios al arrancar con **tope de diseño de 5.000**.
Consecuencias: plan **Supabase Pro** (instancia Small/Medium) basta; no hace falta Team. Pro incluye 500 conexiones
Realtime concurrentes; con 5.000 socios y ~10 % de concurrencia en pico estamos en el límite, por eso se desactiva el
tope de gasto (spend cap) para poder ampliar cuota sin corte. El feed sigue en *fan-out on read* (D-010) y la tabla
`feed_items` queda preparada pero inactiva. Las particiones mensuales de mensajes se mantienen porque son baratas y
facilitan la retención.

## D-002 · Flutter 3.47.9 (N‑1) fijado con FVM
La estable más reciente el 16/11/2026 es 3.50.0 (11/11/2026); N‑1 = **3.47.9** (Dart 3.13.7). Fijado en `.fvmrc`.

## D-003 · Toda la Data API pasa por el esquema `api`
Solo se expone `api` en `config.toml`. Cada módulo vive en su esquema (no expuesto). Las funciones de `api` son
`security invoker` (RLS aplica) salvo las que necesitan escribir en filas de otros usuarios (notificaciones, colas),
que son `security definer` con `set search_path = ''` y comprobación explícita de membresía.
En la app, todos los repositorios dependen de una interfaz `ApiClient.rpc()` → fácil de simular en tests.

## D-004 · Modelos Dart escritos a mano, codegen solo donde aporta
Riverpod con `riverpod_generator` y Drift con `drift_dev` (obligatorios). Los modelos de dominio son clases inmutables
con `fromJson` manual: menos tiempo de build y sin dependencia de `freezed`.

## D-005 · Fuentes empaquetadas
DM Sans y Sora se incluyen como TTF (licencia OFL, obtenidas de Fontsource) en lugar de `google_fonts`, para no
enviar la IP del usuario a Google en tiempo de ejecución (RGPD) y funcionar offline.

## D-006 · Proveedor OIDC de pruebas propio (`oidc-provider` de panva) en Docker
El prompt sugiere mock-oauth2-server o Keycloak. Se usa un contenedor Node con `oidc-provider` (implementación OIDC
certificada) porque permite emitir exactamente el claim `icex_member_verified` igual que hará WordPress, con dos
usuarios semilla (verificado y no verificado) y sin configuración de reinos. Imagen base `node:22-alpine` (Docker Hub).

## D-007 · Proveedor `custom:icex-alumni` dado de alta por Admin API
Los proveedores OIDC personalizados de Supabase Auth (GA abril 2026) no se configuran en `config.toml`; se crean con la
Admin API (`POST /auth/v1/admin/custom-providers`). `scripts/setup-local-auth.sh` lo hace en local y el runbook explica
producción.

## D-008 · Verificación de socio en dos capas
1. **Before User Created hook** (SQL): rechaza el alta si el ID token no trae `icex_member_verified = true`.
2. **Custom Access Token hook** (SQL): en cada emisión/refresh de JWT comprueba `identity.members.status = 'active'`
   y añade `user_role`; si el socio está dado de baja, devuelve error → no hay sesión nueva.
3. **RLS**: todas las políticas exigen `identity.is_member()` (fila activa). Un usuario de Auth sin membresía activa
   no lee ni escribe nada aunque tenga un JWT válido.
El cron diario (`identity.sync_memberships`) marca bajas y revoca sesiones (`auth.sessions`/`auth.refresh_tokens`).

## D-009 · Mensajes particionados por mes **por rango de UUIDv7**
Una tabla particionada exige que la PK contenga la clave de partición. Como el id es UUIDv7 (ordenado por tiempo),
se particiona por `RANGE (id)` con límites calculados del primer UUIDv7 de cada mes. Así `id` sigue siendo PK única
→ idempotencia por id sin columnas extra. `pg_cron` crea las particiones de los 3 meses siguientes.

## D-010 · Feed fase 1 = fan-out on read
`api.get_feed(cursor)` une seguidos + clubs + novedades oficiales con índice `(autor_id, creado desc)` y keyset
`(creado, id)`. `feed.feed_items` existe sin uso para migrar a fan-out on write si algún día hace falta.

## D-011 · IdP de pruebas en red Docker TEST-NET-3 con TLS de desarrollo
Supabase Auth exige issuer **HTTPS** y bloquea issuers que resuelvan a IPs privadas (protección SSRF, también en
tiempo de ejecución). En local: el IdP vive en la red `icex-atlas-idpnet` (203.0.113.0/24, rango de documentación
RFC 5737, no privado) como `idp.icex-atlas.test`, con certificado firmado por una CA de desarrollo
(`scripts/dev-certs.sh`). `scripts/setup-local.sh` conecta el contenedor de Auth a esa red y añade la CA a su almacén.
En el host, `idp.icex-atlas.test → 127.0.0.1`. Funciona en Linux, CI y Docker Desktop sin iptables.
En producción no aplica nada de esto: WordPress tiene un dominio público con certificado real.

## D-012 · `custom_claims_allowlist` obligatorio en el proveedor
Supabase Auth descarta los claims no estándar del ID token salvo los incluidos en `custom_claims_allowlist` del
proveedor. Sin `icex_member_verified` en esa lista **ningún socio nuevo podría entrar** (el hook lo rechazaría).
Los claims permitidos llegan a `raw_user_meta_data.custom_claims`. Se configura en local (setup-local.sh) y es un paso
explícito del runbook de producción y de PARADAS_HUMANAS.

## D-013 · Los hooks de Auth requieren reiniciar el stack
Cambios en `[auth.hook.*]` de `config.toml` no se aplican con `db reset`: hace falta `supabase stop && supabase start`.
Detectado al ver que un no socio entraba con los hooks recién configurados. El test de integración
`scripts/e2e/auth.test.mjs` cubre ahora el rechazo de no verificados contra el stack real.

## D-014 · Embeddings de 384 dimensiones (gte-small en el propio Edge Runtime)
`orientador.documents.embedding` es `vector(384)`. En producción el proveedor por defecto es `gte-small`, que
Supabase ejecuta dentro del Edge Runtime (`Supabase.ai.Session`): los textos de perfiles y publicaciones no salen
de la región de Supabase. En desarrollo/tests: `MockEmbeddings` (feature hashing determinista). Cambiar a otro
modelo con otra dimensión exige una migración del índice HNSW. El LLM que redacta los pasos es intercambiable
(`LLM_PROVIDER`: mock | openai-compatible | anthropic) y su elección es una parada humana. Los alumni sugeridos
salen siempre de la búsqueda vectorial (nunca del LLM), así no se inventan personas.

## D-015 · Linter estricto: very_good_analysis 11 con tres excepciones
`public_member_api_docs` (es una app, no un paquete), `lines_longer_than_80_chars` (usamos `dart format` con
`page_width: 100`) y `unnecessary_type_name_in_constructor`/`unnecessary_const_in_enum_constructor` (sintaxis
abreviada de constructores de Dart 3.13; mantenemos la clásica, que es la que usa el ecosistema Flutter).
Además: `strict-casts`, `strict-inference`, `strict-raw-types`. `flutter analyze` debe dar 0 avisos.

## D-016 · Accesibilidad: dos colores de fase oscurecidos un 5-10 %
Los badges de fase llevan texto blanco de 11 px en negrita (no cuenta como «texto grande» en WCAG). Con los colores
exactos del mockup, Fase 0 (#8A7E75, 3,95:1) y Fase II (#DA4620, 4,31:1) no llegaban al 4,5:1 de WCAG 2.2 AA. Se usan
#7C7169 (4,75:1) y #CF431E (4,69:1): visualmente casi idénticos. Un test (`test/core/core_test.dart`) comprueba el
contraste de todas las combinaciones de texto/fondo del tema.

## D-017 · Panel de administración en Flutter web, autorización solo en el servidor
`/admin` es una app Flutter web mínima (Resumen, Novedades, Denuncias, Clubs, Socios) que usa el mismo login
OIDC y el esquema `api`. La comprobación de rol en el cliente es solo de experiencia de usuario: cada `api.admin_*`
valida `identity.is_admin()`/`is_moderator()` en PostgreSQL (cubierto por pgTAP). Moderación ve Resumen y Denuncias;
solo administración publica novedades, gestiona clubs, cambia roles y suspende socios.

## D-018 · Firebase opcional en compilación
El plugin Gradle `com.google.gms.google-services` (4.5.0) solo se aplica si existe `android/app/google-services.json`,
y `Firebase.initializeApp()` está protegido. Así la app compila y se prueba en local y en CI sin proyecto Firebase,
que es una parada humana. Con la configuración presente (inyectada por CI desde secretos) el push se activa sin
cambiar código. En iOS, `Runner.entitlements` declara `aps-environment`.

## D-019 · Release: Fastlane y CI sin publicar en tiendas
Los flujos `release-mobile.yml` suben solo a **TestFlight** y a la **pista interna** de Play como borrador
(`skip_submission`, `release_status: draft`). Pasar a producción en las tiendas es siempre una acción humana en cada
consola. El despliegue del backend (`deploy-backend.yml`) es manual (`workflow_dispatch`) y producción exige
aprobación del *environment* de GitHub. El seed nunca se aplica fuera de local.

## D-020 · Navegación con `StatefulShellRoute.indexedStack`
Las cinco pestañas (Inicio, Red, Mapa, Mensajes, Orientador) son ramas de un `StatefulShellRoute.indexedStack`
de go_router en lugar de un `ShellRoute`. Cada pestaña conserva su `Navigator`, su scroll y sus datos al cambiar
de pestaña, como en Instagram o LinkedIn; antes cada cambio destruía la página (el feed se recargaba y el
Orientador perdía sus respuestas). Volver a tocar la pestaña activa la lleva arriba (`tabReselectedProvider`).
Las hojas inferiores que se abren desde una pestaña usan `useRootNavigator: true` para cubrir la barra inferior.

## D-021 · Estado compartido de publicaciones (`PostOverrides`)
Recomendar, comentar y borrar se aplican sobre un único estado (`postOverridesProvider`, keepAlive por usuario)
que leen todas las tarjetas (`ConnectedPostCard`), en lugar de que cada lista tenga su copia. Así una publicación
se ve igual en Inicio, en el perfil y en el detalle. El estado se limpia al refrescar el feed y al cambiar de
usuario. Las peticiones de Recomendar en curso bloquean toques repetidos sobre la misma publicación.

## D-022 · Servicios de sesión dependen de `sessionUserIdProvider`
Push, presencia, no leídos y las suscripciones de Realtime dependen del id del usuario (`sessionUserIdProvider`,
un `select` sobre la sesión) y no del estado de sesión completo. El estado cambia cada vez que se recarga el perfil
(editar, cambiar foto, privacidad) y antes eso reiniciaba esos servicios; el de push, al pararse, daba de baja el
token del dispositivo. `refreshMe()` ya no cierra la sesión ante un fallo de red.

## D-023 · Diálogos con campo de texto como `StatefulWidget`
Todo diálogo con `TextField` crea y libera su `TextEditingController` en su propio `State`
(`lib/shared/widgets/dialogs.dart`). Liberarlo tras `await showDialog(...)` provocaba
«A TextEditingController was used after being disposed» durante la animación de cierre. Publicar y compartir
en la red usan ahora una pantalla de composición completa (`/publicar`) en lugar de un diálogo.

## D-024 · Cambio de cuenta con `prompt=login` y enlace a «Hazte socio»
El proveedor de identidad (WordPress en producción, el IdP simulado en local) recuerda la sesión. Tras un
«acceso solo para socios», volver a entrar reutilizaba en silencio la misma cuenta no socia. Ahora, tras un acceso
denegado o un cierre de sesión, y en «Entrar con otra cuenta», la app pide `prompt=login` y `max_age=0` (OIDC
estándar; Supabase Auth reenvía estos parámetros al proveedor). El IdP de pruebas (`oidc-provider`) los respeta;
**hay que comprobar en la copia de pruebas de WordPress (C2) que el plugin OpenID Connect Server también lo hace**.
Si no, el usuario tendría que cerrar sesión en la web para cambiar de cuenta.
La web de la asociación es `icex-alumni.com` (antes la app apuntaba a `icex-alumni.es`, que no existe), y a quien
no es socio se le envía a `MEMBERSHIP_URL` (`/hazte-alumni/`). Si el usuario vuelve a la app sin completar el acceso,
el botón se reactiva a los pocos segundos.

## D-025 · Acceso rápido de desarrollo
En local, la portada muestra «Modo desarrollo» con cuentas de prueba (ana, javier, laura y pedro sin membresía) que
entran con email y contraseña, sin navegador. Las cuentas están en `supabase/seed_dev_accounts.sql`, aplicado por
`setup-local.sh` y por `supabase db reset`. El proveedor Email está activo solo en `config.toml` (local), y
`identity.before_user_created` sigue rechazando cualquier alta que no venga de OIDC. La app solo muestra el panel con
`DEV_LOGIN=true` y `AppEnv.devLogin` lo ignora en producción (lo comprueba un test). Ver `docs/autenticacion.md`.

## D-026 · Estilo de marca en toda la app
La estética de la portada se lleva a todas las pantallas (`shared/widgets/brand.dart`): barra superior roja, logo
sobre una pastilla blanca, cabecera `HeroHeader` con degradado rojo, globo de puntos, barra amarilla, título en
blanco y borde de «hoja» donde empieza el contenido. Los contadores sobre rojo son amarillos y la fase sobre rojo
va en una pastilla blanca. El gris secundario se oscurece a `#57504D` (7,9:1 sobre blanco).

## D-027 · Feed para leer y Orientador sencillo
En el feed solo se intercala, una vez, el carrusel de sugerencias de personas. Se quitan el anuncio del Orientador y
«La comunidad en cifras». Los textos largos se recortan a 6 líneas con un botón «Leer más» / «Mostrar menos», y el
detalle de la publicación muestra el texto completo. El Orientador queda en una pregunta, el contexto (fase, país y
sector, rellenado con el perfil) y un botón, sin sugerencias prefabricadas ni iconos «mágicos».

## D-028 · Rendimiento: medir con presupuestos, no con relojes
Los tests de latencia cuentan peticiones y reconstrucciones (`test/performance`), que es lo que determina la
latencia percibida y es estable en CI. Cambios que derivan de ellos: el total de no leídos ya no se pide dos veces
(la lista de conversaciones reutiliza `unreadProvider`); las ráfagas de Realtime se agrupan en una consulta
(`Debouncer`, 400 ms) para contadores, conversaciones y «marcar leído»; las URL firmadas se piden una vez aunque
varios avatares iguales las soliciten a la vez; las imágenes se decodifican al tamaño en pantalla; el
desvanecido de «Leer más» es un degradado en lugar de un `ShaderMask`. La fluidez real se mide en un móvil en modo
profile (`scripts/perf-app.sh`, `integration_test/`).

## D-029 · Concurrencia: lo que no puede depender del orden de llegada
Pruebas con decenas de conexiones reales (`supabase/stress/concurrency.py`). Reglas que salen de ellas:
- **Id de mensaje = UUID v7 con fecha no futura** (±5 min de reloj). Ordena la conversación y los no leídos; un id
  aleatorio o del futuro quedaba «siempre el último». Se admiten ids antiguos: reintentos de mensajes escritos sin
  cobertura.
- **Lo que avanza no retrocede:** el «último mensaje» de la conversación y el puntero de leído del remitente solo
  avanzan. Un mensaje que llega tarde cuenta como no leído para el destinatario (para él es nuevo).
- **`mark_read` bloquea su fila antes de contar.** Antes, un envío simultáneo podía sumar +1 y el recuento lo pisaba
  (un mensaje sin aviso).
- **Objetos que desaparecen:** seguir, escribir, recomendar, comentar, compartir o unirse a algo que otro borra en
  ese instante devolvía la violación de clave ajena en crudo. Ahora se bloquea (`FOR KEY SHARE`) y responde
  «no encontrado» (P0002). La app también traduce 23503 a «no encontrado».
- **Orden de bloqueo único** (socio → conversación → mensajes) en `send_message` y `delete_my_account`.
- **Notificaciones agrupadas con `INSERT … ON CONFLICT`**: atómico, sin depender de bloqueos indirectos.

## D-030 · Mantenimiento de particiones sin cortar envíos
`ensure_partitions` crea las particiones fuera de línea, mueve las filas que hubieran caído en la partición por
defecto y las adjunta. Pide todos los bloqueos al principio con `lock_timeout` de 100 ms (menor que
`deadlock_timeout`): si choca con envíos en curso, cede el mantenimiento y reintenta; nunca aborta un mensaje.

## D-031 · RLS y funciones `SECURITY DEFINER` por rendimiento
Con RLS activo, Postgres no usa índices con operadores no «leakproof» (PostGIS `&&`/`<->`, `LIKE` de trigramas).
`alumni_near`, `map_clusters` y `search_directory` pasan a `SECURITY DEFINER`: exigen socio activo
(`require_member`) y aplican ellas mismas los filtros (socio activo, visibilidad, bloqueos). Tests en
`080_concurrency_rules`. La política de lectura de posts se reescribe como expresión con subconsultas iniciales
(misma regla que `feed.can_view`, evaluada una vez por consulta en vez de por fila).

## D-032 · Agregados en caché para vistas globales
Mapa a zoom ≤ 6 y cifras de la comunidad salen de agregados que refresca pg_cron cada 10 min. Si la caché no
existe o tiene más de 15 min, se calcula en vivo (también tras un `db reset`). Una celda con una sola persona se
comprueba en vivo antes de mostrarla. Coste: un socio nuevo tarda hasta 10 min en aparecer en la vista mundial.
Las sugerencias puntúan solo candidatos sacados por índice (amigos de amigos y los 300 más seguidos de cada grupo).

## D-033 · Directorio: solo se busca por lo que todos pueden ver
La columna de búsqueda incluía empresa, cargo y ciudad aunque el socio los ocultara: se le encontraba por el dato
oculto. Ahora solo indexa los campos visibles para todos los socios. Las bajas ya no aparecen en el directorio,
el mapa ni «cerca de ti».

## D-034 · Avisos push: vaciar la cola, en paralelo y sin reenvíos
`push-dispatcher` procesaba como mucho 200 eventos por minuto, de uno en uno, y un fallo en un lote hacía reenviar
todo el lote. Ahora vacía la cola por lotes dentro de 45 s (el cron es cada minuto y la visibilidad en cola es de
120 s: no se solapan), envía con 16 conexiones a FCM, aísla los fallos por token, descarta tras 5 lecturas un
mensaje que falla siempre y pide el token OAuth de FCM una sola vez aunque haya envíos simultáneos.

## D-035 · Promoción en curso calculada
La promoción en curso es `año − 1975` (2026 → 51ª) en la base de datos (`profiles.current_promocion()`) y en la
app (`currentPromocion()`); la app usa el valor que envía el servidor en `community_stats`. Si cambia el
calendario se fija sin desplegar con la clave `promociones.actual` de `config.app_config`. Quien se da de alta en
la promoción en curso sin fase en el IdP empieza en Fase 0. El logotipo ya no lleva el sello del 50 aniversario.

## D-036 · Orientador sin texto libre
El Orientador solo pide fase, país y sector (rellenos con el perfil). La Edge Function ya admitía la consulta
vacía y genera la pregunta a partir del contexto.

## D-037 · Beta abierta con email y contraseña
Para tener más probadores, la beta (entorno staging) permite crear cuenta con correo y contraseña sin ser socio.
- **Backend.** `config.app_config['access.mode']` = `open_beta` admite el proveedor `email` en el hook de alta. El
  alta crea un socio con `identity.members.origen = 'beta'`; con `alumni` el registro se cierra. El flujo OIDC de
  socios no cambia.
- **App.** `AUTH_MODE=password` muestra la portada beta, el registro, el acceso, la recuperación y la contraseña
  nueva.
- **Promoción.** 0 = sin promoción. Las cuentas beta la declaran; los socios la traen del IdP.
- **Despliegue.** `scripts/deploy/configure_supabase.py` deja el proyecto configurado por la Management API (Auth,
  API, Vault, modo, secretos) y `smoke_test.py` lo comprueba.
- **Distribución.** Android por Firebase App Distribution e iOS por TestFlight (`release-beta.yml`).

Guía: `docs/beta.md`.

## D-038 · Beta inicial: solo Android, planes gratuitos y prueba de carga por la API pública
- **Alcance.** La primera beta es solo Android (Firebase App Distribution). El job de iOS de `release-beta.yml`
  queda preparado pero solo se ejecuta con la variable de repositorio `IOS_BETA_ENABLED=true`.
- **Coste cero.** Supabase en plan gratuito (las funciones que usamos, incluidos los hooks de Auth y el SMTP
  propio, están incluidas). Riesgos asumidos: pausa tras 7 días sin actividad (lo evita `keepalive.yml`) y sin
  copias automáticas. Se pasa a Pro cuando la beta tenga uso real o al abrirla a socios.
- **Correo.** SMTP de Mailrelay, que ICEX Alumni ya paga: mismo dominio remitente que los boletines.
- **Prueba de carga.** `scripts/load/carga.py` (Python + aiohttp, sin binarios externos) entra por Auth, PostgREST y
  Realtime como la app, en escalones de usuarios simultáneos, contra un proyecto aparte («carga»), nunca contra el
  de la beta. Complementa a `supabase/stress/`, que mide la base de datos directamente. Lo previsible es que el
  primer límite del plan gratuito sean las 200 conexiones simultáneas de Realtime.
- **Borrado de cuenta.** La prueba de carga destapó que, si los dos participantes borraban su cuenta, quedaba la
  conversación vacía. `20261126000100` la borra al irse el último miembro.

