# shellcheck shell=bash
# Carga en el shell las variables de la Supabase local: API_URL, DB_URL, ANON_KEY, SERVICE_ROLE_KEY.
# Uso: source scripts/lib/supabase-env.sh
#
# El formato de `supabase status -o env` cambia entre versiones de la CLI (comillas, `export`,
# espacios alrededor del "=", y en versiones nuevas las claves pueden llamarse solo
# PUBLISHABLE_KEY/SECRET_KEY). Aquí se aceptan todas las variantes y, si aun así falta algo,
# se explica qué pasa en lugar de fallar con "unbound variable".

# Usa la CLI global si existe (brew/scoop) y, si no, `npx supabase` (lo que usa quien solo tiene Node).
if command -v supabase >/dev/null 2>&1; then
  __supabase_cli=(supabase)
else
  __supabase_cli=(npx -y supabase)
fi

__supabase_status="$("${__supabase_cli[@]}" status -o env 2>&1 || true)"

__supabase_get() {
  # Devuelve el valor de la clave $1 o vacío. Tolera: KEY=v · KEY="v" · export KEY="v" · KEY = "v"
  printf '%s\n' "${__supabase_status}" \
    | sed -nE "s/^[[:space:]]*(export[[:space:]]+)?$1[[:space:]]*=[[:space:]]*\"?([^\"]*)\"?[[:space:]]*\$/\\2/p" \
    | head -n1
}

API_URL="$(__supabase_get API_URL)"
DB_URL="$(__supabase_get DB_URL)"
ANON_KEY="$(__supabase_get ANON_KEY)"
SERVICE_ROLE_KEY="$(__supabase_get SERVICE_ROLE_KEY)"
# CLI recientes: claves nuevas en lugar de (o además de) las JWT clásicas.
[[ -n "${ANON_KEY}" ]] || ANON_KEY="$(__supabase_get PUBLISHABLE_KEY)"
[[ -n "${SERVICE_ROLE_KEY}" ]] || SERVICE_ROLE_KEY="$(__supabase_get SECRET_KEY)"

if [[ -z "${API_URL}" || -z "${DB_URL}" || -z "${ANON_KEY}" || -z "${SERVICE_ROLE_KEY}" ]]; then
  {
    echo "✗ No he podido leer la configuración de la Supabase local con 'supabase status -o env'."
    echo "  Comprueba que 'supabase start' terminó bien y que estás en la raíz del repositorio."
    __v="$("${__supabase_cli[@]}" --version 2>/dev/null | head -n1)"
    echo "  Versión de la CLI: ${__v:-desconocida}"
    echo "  Salida recibida (claves recortadas):"
    printf '%s\n' "${__supabase_status}" | sed -E 's/(=[[:space:]]*"?[^"]{12})[^"]*/\1…/' | sed 's/^/    /'
  } >&2
  unset -f __supabase_get; unset __supabase_status __supabase_cli __v
  return 1 2>/dev/null || exit 1  # `return` si se carga con source (no cierra tu terminal)
fi
export API_URL DB_URL ANON_KEY SERVICE_ROLE_KEY
unset -f __supabase_get
unset __supabase_status __supabase_cli
