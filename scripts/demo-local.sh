#!/usr/bin/env bash
# Demo en local: cambia los datos de desarrollo de la Supabase local por la comunidad de la demo.
#
#   ./scripts/demo-local.sh              # pone la demo (borra los datos locales de desarrollo)
#   ./scripts/demo-local.sh --restaurar  # vuelve a los datos de desarrollo
#
# Antes: tener la app arrancada con  AUTH_MODE=password ./scripts/start-local.sh
# Cuentas (contraseña DEMO_PASSWORD, por defecto demo1234):
#   nueva@demo.icexatlas.invalid · marina@demo.icexatlas.invalid · javier@demo.icexatlas.invalid
# Guion: docs/demo.md
set -euo pipefail
cd "$(dirname "$0")/.."

say() { printf '\n→ %s\n' "$*"; }
die() { printf '✗ %s\n' "$*" >&2; exit 1; }

if command -v supabase >/dev/null 2>&1; then cli=(supabase); else cli=(npx -y supabase); fi
"${cli[@]}" status >/dev/null 2>&1 || die "La Supabase local no está arrancada. Lanza antes: AUTH_MODE=password ./scripts/start-local.sh"

if [[ "${1:-}" == "--restaurar" ]]; then
  say "Volviendo a los datos de desarrollo"
  "${cli[@]}" db reset
  ./scripts/setup-local.sh
  exit 0
fi

# Python con psycopg: el del sistema si ya lo tiene; si no, un entorno propio fuera del repo
# (en Mac, pip y python3 suelen ser Pythons distintos y Homebrew no deja instalar paquetes).
py=python3
if ! "${py}" -c 'import psycopg' 2>/dev/null; then
  venv="${HOME}/.venvs/icex"
  if [[ ! -x "${venv}/bin/python" ]]; then
    say "Preparando Python para los scripts (${venv}, una sola vez)"
    python3 -m venv "${venv}"
  fi
  py="${venv}/bin/python"
  "${py}" -c 'import psycopg' 2>/dev/null || "${py}" -m pip install --quiet "psycopg[binary]"
fi

say "Base de datos local vacía (sin los datos de desarrollo)"
"${cli[@]}" db reset --no-seed

# shellcheck source=lib/supabase-env.sh
source scripts/lib/supabase-env.sh

say "Registro con correo activado (beta abierta)"
DB_URL="${DB_URL}" "${py}" - <<'PY'
import os, psycopg
with psycopg.connect(os.environ["DB_URL"], autocommit=True) as c:
    c.execute("""insert into config.app_config (key, value) values ('access.mode', '"open_beta"')
                 on conflict (key) do update set value = excluded.value""")
PY

say "Comunidad de la demo"
SUPABASE_URL="${API_URL}" SUPABASE_ANON_KEY="${ANON_KEY}" SUPABASE_SERVICE_ROLE_KEY="${SERVICE_ROLE_KEY}" \
  DB_URL="${DB_URL}" DEMO_CONFIRMAR=local DEMO_PASSWORD="${DEMO_PASSWORD:-demo1234}" \
  "${py}" scripts/demo/seed_demo.py

cat <<EOF

✓ Demo lista. En la app, cierra sesión si estabas dentro y entra con:
    nueva@demo.icexatlas.invalid    (el primer día)
    marina@demo.icexatlas.invalid   (perfil completo y mensajes)
    javier@demo.icexatlas.invalid   (segundo dispositivo, chat en directo)
  Contraseña: ${DEMO_PASSWORD:-demo1234}
  Para volver a los datos de desarrollo: ./scripts/demo-local.sh --restaurar
EOF
