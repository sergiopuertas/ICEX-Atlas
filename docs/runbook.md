# Runbook de operación

Procedimientos para poner en marcha y operar ICEX Atlas en Supabase Cloud. Los pasos que requieren contratar o
firmar algo están en `PARADAS_HUMANAS.md`. Este documento supone que esas paradas ya se han resuelto.

Entornos: **staging** y **production**. Son dos proyectos Supabase en la misma región UE y cada uno tiene su
*environment* de GitHub con sus propios secretos.

## 1. Primer despliegue de un entorno

1. **Enlazar y aplicar migraciones.** Ejecuta en GitHub Actions el flujo *Deploy backend* (`deploy-backend.yml`), eligiendo el entorno.
   El flujo hace `supabase link`, `db push --dry-run`, `db push` y `functions deploy` de las seis funciones.
   En local, el equivalente es:
   ```bash
   supabase link --project-ref <ref> -p "$SUPABASE_DB_PASSWORD"
   supabase db push --dry-run && supabase db push
   for f in push-dispatcher orientador orientador-indexer media-upload account-delete membership-sync; do
     supabase functions deploy "$f" --project-ref <ref>; done
   ```
   El seed (`supabase/seed.sql`) es **solo para local**. `db push` no lo aplica.

2. **Ajustes de API** (Dashboard → Project Settings → Data API):
   - *Exposed schemas*: **solo `api`**. Quita `public` y `graphql_public`.
   - *Extra search path*: `api, extensions`.

3. **Hooks de Auth** (Dashboard → Authentication → Hooks, o `supabase config push`):
   - *Before User Created* → función Postgres `identity.before_user_created`.
   - *Custom Access Token* → función Postgres `identity.custom_access_token`.

4. **Auth: URLs y opciones** (Authentication → URL Configuration):
   - *Site URL*: `es.icexalumni.atlas://login-callback`.
   - *Redirect URLs*: `es.icexalumni.atlas://login-callback` y la URL del panel admin (`https://admin.<dominio>/`).
   - Desactiva el registro por email, el teléfono y el resto de proveedores. Solo debe quedar el OIDC.

5. **Proveedor OIDC `custom:icex-alumni`** (por Admin API; ver D-007 y D-012). Hay que incluir la lista de claims permitidos,
   o el hook no ve `icex_member_verified` y rechaza a todo el mundo:
   ```bash
   curl -X POST "https://<ref>.supabase.co/auth/v1/admin/custom-providers" \
     -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" -H 'Content-Type: application/json' \
     -d '{"provider_type":"oidc","identifier":"custom:icex-alumni","name":"ICEX Alumni",
          "client_id":"<OIDC_CLIENT_ID>","client_secret":"<OIDC_CLIENT_SECRET>",
          "issuer":"https://<dominio-wordpress>","scopes":["openid","profile","email"],
          "pkce_enabled":true,"enabled":true,
          "custom_claims_allowlist":["icex_member_verified","icex_promocion","icex_fase"]}'
   ```
   Para modificarlo, usa `PUT .../custom-providers/custom:icex-alumni` con el mismo cuerpo.

6. **Realtime** (Realtime → Settings): desactiva **«Allow public access»**. Los canales `conversation:*` y `user:*`
   son privados y se autorizan con RLS sobre `realtime.messages`.

7. **Secretos de Vault para Cron** (SQL Editor). Los usan las tareas `pg_cron` para invocar las Edge Functions:
   ```sql
   select vault.create_secret('https://<ref>.supabase.co', 'project_url');
   select vault.create_secret('<service_role_key>', 'service_role_key');
   ```

8. **Secretos de las Edge Functions.** Ejecuta `supabase secrets set --env-file <fichero> --project-ref <ref>`.
   El fichero sigue la sección «Edge Functions» de `.env.example`:
   `LLM_PROVIDER`, `LLM_BASE_URL`, `LLM_API_KEY`, `LLM_MODEL`, `EMBEDDINGS_PROVIDER=supabase-gte-small`, `PUSH_PROVIDER=fcm`,
   `FCM_SERVICE_ACCOUNT_JSON`, `WP_BASE_URL`, `WP_SYNC_TOKEN`, `MEMBERSHIP_MAX_REVOKE_RATIO`, `ADMIN_ALLOWED_ORIGINS`.

9. **Storage.** Los buckets (`avatars`, `post-media`) y sus políticas los crean las migraciones. Comprueba que siguen siendo **privados**.

10. **Comprobación.** Entra con un socio de prueba de la copia de WordPress y verifica:
    - el feed carga;
    - un no socio recibe «acceso solo para socios»;
    - `select * from cron.job_run_details order by start_time desc limit 20;` no muestra errores;
    - las Edge Functions no tienen errores en *Logs*.

## 2. Despliegues habituales

- **Base de datos:** solo con migraciones nuevas (`supabase migration new <nombre>`). Nunca se edita el esquema en el Dashboard.
  La CI falla si hay *drift*. Primero se despliega en staging, después en producción, con el mismo flujo.
- **Edge Functions:** el mismo flujo *Deploy backend*. Son compatibles hacia atrás con la versión anterior de la app.
- **App móvil:** flujo *Release mobile* (`release-mobile.yml`). Sube un borrador a la pista interna de Play y a TestFlight.
  La promoción a producción en las tiendas se hace **a mano** en las consolas.
- **Panel admin:** `cd admin && flutter build web --dart-define-from-file=env/production.json`, y luego se publica `build/web`
  en un hosting estático (p. ej. Cloudflare Pages o Netlify, en la UE). Su origen debe estar en `ADMIN_ALLOWED_ORIGINS` y en las *Redirect URLs*.

## 3. Rotación de claves

| Clave | Cómo | Efecto |
|---|---|---|
| Claves API (`anon`/`publishable`, `service_role`/`secret`) | Dashboard → API Keys → crear nueva, desplegar, revocar la antigua | Actualiza el secreto Vault `service_role_key` (`vault.update_secret`), los secretos de CI y la app/panel si cambia la publishable |
| JWT signing key | Dashboard → JWT Keys → rotar (las asimétricas permiten solapamiento) | Las sesiones se renuevan solas |
| `OIDC_CLIENT_SECRET` | Cambiar en WordPress (`OIDC_CLIENTS`) y en el proveedor (`PUT` del paso 1.5) en la misma ventana | Los inicios de sesión fallan unos minutos |
| `WP_SYNC_TOKEN` | Cambiar `ICEX_ATLAS_SYNC_TOKEN` en `wp-config.php` y el secreto de la función | — |
| `FCM_SERVICE_ACCOUNT_JSON` | Nueva clave en Google Cloud IAM, `supabase secrets set`, borrar la antigua | — |
| `LLM_API_KEY` | En el panel del proveedor, y después `supabase secrets set` | Mientras tanto responde el proveedor de respaldo |

Si una clave se filtra, rótala de inmediato y revisa los *Auth logs* y los *API logs* del periodo. Si había datos personales
afectados, la asociación debe valorar la notificación a la AEPD (72 h).

## 4. Copias de seguridad y restauración

- Pro incluye copias diarias. Con **PITR** activado (parada humana) se puede volver a cualquier segundo de los últimos 7 días.
- **Restaurar** (Dashboard → Database → Backups → Point in time): elige el instante y confirma. El proyecto queda
  sin servicio durante la restauración. Después:
  1. Comprueba que los secretos de Vault siguen ahí (`select name from vault.secrets`).
  2. Comprueba que los trabajos cron están activos (`select jobname, active from cron.job`).
  3. Si un socio ejerció el derecho de supresión después del punto restaurado, **repite el borrado**. Antes de restaurar,
     exporta de los logs de `account-delete` los eventos `account_deleted` del periodo afectado.
- **Ensayo trimestral:** restaura staging a un punto anterior y ejecuta la comprobación del paso 1.10.
- Storage no entra en PITR. Los objetos borrados no se recuperan (es lo que pide el RGPD para las bajas).

## 5. Operación diaria

- **Bajas de socios:** `membership-sync` se ejecuta cada día a las 02:15 UTC. Si WordPress devuelve más del 5 % de bajas, se
  detiene sin revocar (lo indican el log y `notifications`). Hay que revisarlo con la asociación antes de subir
  `MEMBERSHIP_MAX_REVOKE_RATIO`.
- **Moderación:** desde el panel admin (denuncias, ocultar, suspender).
- **Particiones de mensajes:** se crean solas (cron mensual `messaging-partitions`, con 4 meses de margen).
  Para comprobarlo: `select inhrelid::regclass from pg_inherits where inhparent = 'messaging.messages'::regclass;`.
- **Colas:** `select * from pgmq.metrics_all();`. Si `push` crece, revisa los logs de `push-dispatcher` y las credenciales de FCM.
- **Rendimiento:** `./scripts/perf.sh` contra staging (con `DB_URL`). El objetivo es p95 < 200 ms en `get_feed` y `search_directory`.

## 6. Mapa

Las teselas de OpenStreetMap (`tile.openstreetmap.org`) **no se pueden usar en producción a esta escala** (política
de uso justo). Antes del lanzamiento:
1. Contrata un proveedor con SLA (MapTiler, Stadia o similar, con servidores en la UE).
2. Pon `MAP_TILE_URL` y `MAP_TILE_ATTRIBUTION` en `app/env/production.json` (secreto `APP_ENV_PRODUCTION_JSON` de CI)
   y publica una nueva versión. La clave del proveedor es pública en la app: restríngela por *bundle id* o *package*
   en el panel del proveedor. Mantén el texto de atribución que exija el proveedor.

## 7. Incidencias frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| Todos los socios ven «acceso solo para socios» | Falta `custom_claims_allowlist` en el proveedor o el hook está desactivado | Pasos 1.3 y 1.5 |
| Los mensajes no llegan en tiempo real | «Allow public access» activado o el JWT no tiene el claim `icex_member_verified` | Paso 1.6, cerrar sesión y volver a entrar |
| No llegan push | Faltan los secretos de Vault, falla `FCM_SERVICE_ACCOUNT_JSON` o el dispositivo no tiene token | Pasos 1.7 y 1.8, y `cron.job_run_details` |
| El orientador responde siempre lo mismo | Falla el proveedor de IA y entra el respaldo | Logs de `orientador` y `LLM_API_KEY` |
| La app da error 404 en RPC | No se expone el esquema `api` | Paso 1.2 |
