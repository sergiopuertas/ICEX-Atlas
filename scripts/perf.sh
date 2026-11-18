#!/usr/bin/env bash
# p95 de get_feed y search_directory con los datos semilla. Falla si alguno >= 200 ms.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=lib/supabase-env.sh
source scripts/lib/supabase-env.sh  # (el script ya hizo cd a la raíz)
out="$(psql "$DB_URL" -X -q -f scripts/perf.sql)"
echo "$out"
grep -q 'OK: p95 < 200 ms' <<<"$out"
