#!/usr/bin/env bash
# Sirve las Edge Functions con Deno en el host (puerto 54400+) contra la Supabase local.
# Útil cuando el contenedor edge-runtime no puede descargar dependencias npm (p. ej. tras
# un proxy corporativo con CA propia). En condiciones normales usa `supabase start`.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=lib/supabase-env.sh
source scripts/lib/supabase-env.sh  # (el script ya hizo cd a la raíz)
set -a; source supabase/functions/.env; set +a
# El IdP/WordPress simulado usa la CA de desarrollo y no debe pasar por proxies.
cat docker/certs/dev-ca.crt ${DENO_CERT:+"$DENO_CERT"} > /tmp/icex-deno-ca.pem
export DENO_CERT=/tmp/icex-deno-ca.pem NO_PROXY="${NO_PROXY:-},idp.icex-atlas.test,127.0.0.1,localhost"
export SUPABASE_URL="$API_URL" SUPABASE_SERVICE_ROLE_KEY="$SERVICE_ROLE_KEY" SUPABASE_ANON_KEY="$ANON_KEY"
port=54400
for fn in orientador orientador-indexer push-dispatcher media-upload account-delete membership-sync; do
  FN_PORT="$port" deno run --no-lock --allow-env --allow-net "supabase/functions/$fn/index.ts" >/tmp/fn-$fn.log 2>&1 &
  echo "$fn → http://127.0.0.1:$port"
  port=$((port + 1))
done
wait
