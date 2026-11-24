#!/usr/bin/env bash
# Mide el rendimiento de scroll (Inicio, Red, Chat) en un MÓVIL FÍSICO conectado, en modo
# profile. En debug o en el emulador los tiempos no son representativos.
# Resultados: app/build/*.timeline_summary.json. Uso: ./scripts/perf-app.sh [-d <dispositivo>]
set -euo pipefail
cd "$(dirname "$0")/../app"
flutter drive --profile \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/scroll_performance_test.dart "$@"
