#!/usr/bin/env bash
# Arranca ICEX Atlas entero en local: Docker → Supabase → IdP de pruebas → emulador Android → app.
#
# Uso (desde la raíz del repositorio):
#   AVD=<nombre-del-emulador> ./scripts/start-local.sh     # arranca también el emulador
#   ./scripts/start-local.sh                               # usa un emulador o dispositivo ya conectado
#   NO_RUN=1 ./scripts/start-local.sh                      # deja el backend y el emulador listos, sin lanzar la app
#
# Variables opcionales: SDK (ruta del Android SDK), FLUTTER_DEVICE (id de dispositivo para flutter run).
set -euo pipefail
cd "$(dirname "$0")/.."

say() { printf '\n\033[1m→ %s\033[0m\n' "$*"; }
fail() { printf '\n✗ %s\n' "$*" >&2; exit 1; }

SDK="${SDK:-$HOME/Library/Android/sdk}"
ADB="$(command -v adb || true)"
[[ -n "$ADB" ]] || ADB="$SDK/platform-tools/adb"
EMULATOR="$SDK/emulator/emulator"

# ── 1. Docker ───────────────────────────────────────────────────────────────────
say "Docker"
if ! docker info >/dev/null 2>&1; then
  if [[ "$(uname)" == "Darwin" ]]; then
    open -a Docker || fail "No encuentro Docker Desktop. Instálalo o arráncalo a mano."
  fi
  for _ in $(seq 1 60); do docker info >/dev/null 2>&1 && break; sleep 2; done
  docker info >/dev/null 2>&1 || fail "Docker no arranca. Ábrelo a mano y repite el script."
fi
echo "  ok"

# ── 2. Entrada de hosts para el IdP de pruebas ──────────────────────────────────
say "Nombre del IdP en /etc/hosts"
if ! grep -q "idp.icex-atlas.test" /etc/hosts; then
  echo "  Se añadirá 127.0.0.1 idp.icex-atlas.test (pide tu contraseña de Mac)"
  echo "127.0.0.1 idp.icex-atlas.test" | sudo tee -a /etc/hosts >/dev/null
fi
echo "  ok"

# ── 3. Supabase local ───────────────────────────────────────────────────────────
say "Supabase local"
if command -v supabase >/dev/null 2>&1; then SUPA=(supabase); else SUPA=(npx -y supabase); fi
"${SUPA[@]}" start -x studio,logflare,vector >/tmp/icex-supabase-start.log 2>&1 || {
  tail -20 /tmp/icex-supabase-start.log
  fail "supabase start ha fallado (salida completa en /tmp/icex-supabase-start.log)"
}
for _ in $(seq 1 60); do "${SUPA[@]}" status >/dev/null 2>&1 && break; sleep 5; done
"${SUPA[@]}" status >/dev/null 2>&1 || fail "Supabase no responde. Espera un minuto y vuelve a ejecutar el script."
echo "  ok"

# ── 4. IdP de pruebas, proveedor OIDC, Vault, app/env/local.json ────────────────
say "Configuración local (setup-local.sh)"
./scripts/setup-local.sh

# ── 5. Emulador Android ─────────────────────────────────────────────────────────
say "Emulador Android"
if ! "$ADB" devices 2>/dev/null | awk 'NR>1 && $2=="device"{found=1} END{exit !found}'; then
  [[ -n "${AVD:-}" ]] || fail "No hay emulador conectado. Indica el AVD: AVD=<nombre> ./scripts/start-local.sh (lista: $EMULATOR -list-avds)"
  [[ -x "$EMULATOR" ]] || fail "No encuentro el emulador en $EMULATOR (define SDK=<ruta del SDK>)."

  AVD_INI="$HOME/.android/avd/$AVD.avd/config.ini"
  if [[ -f "$AVD_INI" ]] && grep -q 'abi.type=arm64' "$AVD_INI" && [[ "$(uname -m)" == "x86_64" ]]; then
    fail "El AVD «$AVD» es arm64 y este Mac es Intel: no arranca. Crea uno con imagen x86_64 (Google APIs) en Device Manager."
  fi

  echo "  Arrancando $AVD con escritura en /system (log: /tmp/icex-emulator.log)"
  nohup "$EMULATOR" -avd "$AVD" -writable-system >/tmp/icex-emulator.log 2>&1 &
  "$ADB" wait-for-device
  for _ in $(seq 1 120); do
    [[ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] && break
    sleep 3
  done
  [[ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] || fail "El emulador no termina de arrancar. Revisa /tmp/icex-emulator.log"
fi
echo "  ok"

# ── 6. Puertos y certificado en el emulador ─────────────────────────────────────
say "Puertos y certificado (android-dev.sh)"
./scripts/android-dev.sh

# ── 7. Java para Gradle ─────────────────────────────────────────────────────────
say "Java para Gradle"
if ! grep -q '^org.gradle.java.home' "$HOME/.gradle/gradle.properties" 2>/dev/null; then
  JH="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
  [[ -n "$JH" ]] || fail "No hay Java 17. Instálalo con: brew install --cask temurin@17"
  mkdir -p "$HOME/.gradle"
  echo "org.gradle.java.home=$JH" >> "$HOME/.gradle/gradle.properties"
  echo "  configurado: $JH"
else
  echo "  ya configurado"
fi

# ── 8. Flutter ──────────────────────────────────────────────────────────────────
say "App"
if [[ "${NO_RUN:-0}" == "1" ]]; then
  echo "  NO_RUN=1: backend y emulador listos. Lanza la app con F5 en VS Code o con:"
  echo "  cd app && flutter run --dart-define-from-file=env/local.json"
  exit 0
fi
cd app
if command -v fvm >/dev/null 2>&1 && [[ -d ../.fvm/flutter_sdk ]]; then FLUTTER=(fvm flutter); else FLUTTER=(flutter); fi
DEVICE_ARGS=()
[[ -n "${FLUTTER_DEVICE:-}" ]] && DEVICE_ARGS=(-d "$FLUTTER_DEVICE")
"${FLUTTER[@]}" pub get >/dev/null
exec "${FLUTTER[@]}" run ${DEVICE_ARGS[@]+"${DEVICE_ARGS[@]}"} --dart-define-from-file=env/local.json
