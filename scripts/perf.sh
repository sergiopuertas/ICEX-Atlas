#!/usr/bin/env bash
# p95 de get_feed y search_directory con los datos semilla. Falla si alguno >= 200 ms.
set -euo pipefail
cd "$(dirname "$0")/.."
DB_URL="$(supabase status -o env 2>/dev/null | grep '^DB_URL=' | cut -d'"' -f2)"
out="$(psql "$DB_URL" -X -q -f scripts/perf.sql)"
echo "$out"
grep -q 'OK: p95 < 200 ms' <<<"$out"
