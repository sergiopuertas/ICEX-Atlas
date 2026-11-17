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
