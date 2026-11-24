#!/usr/bin/env bash
# Configura el entorno local tras `supabase start`:
#   1) registra el proveedor OIDC custom:icex-alumni en Supabase Auth (Admin API)
#   2) guarda en Vault los secretos que usan las tareas Cron para invocar Edge Functions
# Idempotente. Uso: ./scripts/setup-local.sh
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck source=lib/supabase-env.sh
source scripts/lib/supabase-env.sh  # (el script ya hizo cd a la raíz)
OIDC_ISSUER="${OIDC_ISSUER:-https://idp.icex-atlas.test:9010}"
OIDC_CLIENT_ID="${OIDC_CLIENT_ID:-supabase-local}"
OIDC_CLIENT_SECRET="${OIDC_CLIENT_SECRET:-supabase-local-secret}"
PROJECT_ID="$(grep -E '^project_id' supabase/config.toml | cut -d'"' -f2)"

if ! grep -q 'idp.icex-atlas.test' /etc/hosts 2>/dev/null; then
  echo "⚠  Añade '127.0.0.1 idp.icex-atlas.test' a /etc/hosts (una vez): el navegador y Auth deben ver el mismo issuer."
fi

./scripts/dev-certs.sh
[[ -f supabase/functions/.env ]] || cp supabase/functions/.env.local.example supabase/functions/.env
AUTH_CONTAINER="supabase_auth_${PROJECT_ID}"
echo "→ El contenedor de Auth confía en la CA de desarrollo (Supabase Auth exige issuer HTTPS)"
CA_FP="$(openssl x509 -in docker/certs/dev-ca.crt -noout -fingerprint -sha256 | cut -d= -f2 | tr -d :)"
if ! docker exec "${AUTH_CONTAINER}" grep -q "ICEX-ATLAS-DEV-CA ${CA_FP}" /etc/ssl/certs/ca-certificates.crt; then
  { echo "# ICEX-ATLAS-DEV-CA ${CA_FP}"; cat docker/certs/dev-ca.crt; } | docker exec -i -u 0 "${AUTH_CONTAINER}" sh -c 'cat >> /etc/ssl/certs/ca-certificates.crt'
  docker restart "${AUTH_CONTAINER}" >/dev/null
  for _ in $(seq 1 45); do curl -sf --noproxy "*" --max-time 2 "${API_URL}/auth/v1/health" -H "apikey: ${SERVICE_ROLE_KEY}" >/dev/null && break; sleep 1; done
  curl -sf --noproxy "*" --max-time 2 "${API_URL}/auth/v1/health" -H "apikey: ${SERVICE_ROLE_KEY}" >/dev/null \
    || { echo "✗ Auth no vuelve tras reiniciarlo (docker logs ${AUTH_CONTAINER})"; exit 1; }
else
  echo "  ya confiaba"
fi
echo "→ IdP de pruebas (docker compose)"
docker compose -f docker/docker-compose.yml up -d >/dev/null  # construye la imagen si no existe
for _ in $(seq 1 60); do curl -sf --noproxy "*" --max-time 2 --cacert docker/certs/dev-ca.crt "${OIDC_ISSUER}/healthz" >/dev/null && break; sleep 1; done
curl -sf --noproxy "*" --max-time 2 --cacert docker/certs/dev-ca.crt "${OIDC_ISSUER}/healthz" >/dev/null || {
  echo "✗ El IdP de pruebas no responde en ${OIDC_ISSUER}. Mira: docker compose -f docker/docker-compose.yml logs"
  echo "  (¿está '127.0.0.1 idp.icex-atlas.test' en /etc/hosts? ¿el puerto 9010 lo usa otro proceso?)"
  exit 1
}

echo "→ Auth se conecta a la red del IdP (TEST-NET-3, no privada para el filtro SSRF)"
docker network connect icex-atlas-idpnet "${AUTH_CONTAINER}" 2>/dev/null || true

echo "→ Proveedor OIDC custom:icex-alumni (${OIDC_ISSUER})"
body=$(cat <<JSON
{"provider_type":"oidc","identifier":"custom:icex-alumni","name":"ICEX Alumni",
 "client_id":"${OIDC_CLIENT_ID}","client_secret":"${OIDC_CLIENT_SECRET}",
 "issuer":"${OIDC_ISSUER}","scopes":["openid","profile","email"],"pkce_enabled":true,"enabled":true,
 "custom_claims_allowlist":["icex_member_verified","icex_promocion","icex_fase"]}
JSON
)
code=$(curl -s --noproxy "*" -o /tmp/icex-provider.json -w '%{http_code}' -X POST "${API_URL}/auth/v1/admin/custom-providers" \
  -H "apikey: ${SERVICE_ROLE_KEY}" -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" -H 'Content-Type: application/json' -d "${body}")
if [[ "$code" == "200" || "$code" == "201" ]]; then
  echo "  creado"
elif grep -q 'conflict\|already' /tmp/icex-provider.json; then
  curl -s --noproxy "*" -X PUT "${API_URL}/auth/v1/admin/custom-providers/custom:icex-alumni" \
    -H "apikey: ${SERVICE_ROLE_KEY}" -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" -H 'Content-Type: application/json' \
    -d "${body}" >/dev/null && echo "  actualizado"
else
  echo "  ERROR ${code}: $(cat /tmp/icex-provider.json)"; exit 1
fi

echo "→ Secretos de Vault para Cron (project_url, service_role_key)"
psql "${DB_URL}" -v ON_ERROR_STOP=1 -q -o /dev/null <<SQL
select vault.create_secret('http://supabase_kong_${PROJECT_ID}:8000', 'project_url')
 where not exists (select 1 from vault.secrets where name = 'project_url');
select vault.create_secret('${SERVICE_ROLE_KEY}', 'service_role_key')
 where not exists (select 1 from vault.secrets where name = 'service_role_key');
SQL
echo "→ Cuentas de acceso rápido para desarrollo (contraseña: atlas-dev-local)"
psql "${DB_URL}" -v ON_ERROR_STOP=1 -q -o /dev/null -f supabase/seed_dev_accounts.sql

echo "→ Configuración de la app (app/env/local.json)"
cat > app/env/local.json <<JSON
{
  "SUPABASE_URL": "${API_URL}",
  "SUPABASE_ANON_KEY": "${ANON_KEY}",
  "OIDC_PROVIDER": "custom:icex-alumni",
  "AUTH_REDIRECT": "es.icexalumni.atlas://login-callback",
  "APP_ENV": "local",
  "SHOW_DEMO_BANNER": true,
  "DEV_LOGIN": true
}
JSON
echo "✓ Entorno local listo. Usuarios OIDC de prueba: ana, javier, laura (admin), nueva (alta nueva), pedro (no socio)."
echo "  Acceso rápido sin navegador: botones «Modo desarrollo» en la portada (DEV_LOGIN=true)."
