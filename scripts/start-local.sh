#!/usr/bin/env bash
# Arranca ICEX Atlas entero en local: Docker → Supabase → IdP de pruebas → emulador Android → app.
#
# Uso (desde la raíz del repositorio):
#   AVD=<nombre-del-emulador> ./scripts/start-local.sh     # arranca también el emulador
#   ./scripts/start-local.sh                               # usa un emulador ya arrancado
#   NO_RUN=1 ./scripts/start-local.sh                      # deja todo listo sin lanzar la app
#   COLD=1 AVD=… ./scripts/start-local.sh                  # arranque en frío del emulador (si se quedó raro)
#
# Variables opcionales:
#   SDK / ANDROID_HOME   ruta del Android SDK (por defecto ~/Library/Android/sdk)
#   FLUTTER_DEVICE       id del dispositivo para flutter run (por defecto, el emulador arrancado)
#
# Qué hace distinto de un `flutter run` a secas (y por qué):
#   · Usa SIEMPRE el adb del SDK, el mismo que usa Flutter. Con dos adb de versiones distintas
#     (p. ej. uno de Homebrew en el PATH) cada uno mata el servidor del otro: el dispositivo
#     «desaparece», `flutter run` se queda en «Installing…» o dice «No supported devices».
#   · Arranca el emulador EN PARALELO con Docker/Supabase (antes iba después: minutos perdidos).
#   · Al arrancar, cierra Chrome y la app y vuelve al inicio: el Quick Boot restaura la última
#     pantalla (la web de ICEX Alumni del IdP de pruebas), que se veía «al arrancar».
#   · Espera a que el gestor de paquetes esté listo antes de instalar (si no, «Installing…» eterno).
#   · Hace `adb root` ANTES de `adb reverse`: `adb root` reinicia adbd y borraba los puertos.
set -euo pipefail
cd "$(dirname "$0")/.."

T0=$SECONDS
STEP_T=$SECONDS
say()  { printf '\n\033[1m→ %s\033[0m\n' "$*"; STEP_T=$SECONDS; }
done_() { printf '  ok (%ss)\n' "$((SECONDS - STEP_T))"; }
warn() { printf '  ⚠  %s\n' "$*"; }
fail() { printf '\n✗ %s\n' "$*" >&2; exit 1; }

# ── 0. Herramientas ─────────────────────────────────────────────────────────────
say "Comprobaciones previas"
SDK="${SDK:-${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}}"
ADB="$SDK/platform-tools/adb"
EMULATOR="$SDK/emulator/emulator"
[[ -x "$ADB" ]] || ADB="$(command -v adb || true)"
[[ -n "$ADB" && -x "$ADB" ]] || fail "No encuentro adb. Instala «Android SDK Platform-Tools» o define SDK=<ruta del SDK>."
# El resto de scripts (android-dev.sh) usarán este mismo adb.
ADB_DIR="$(dirname "$ADB")"
export PATH="$ADB_DIR:$PATH"
other_adb="$(type -ap adb | grep -v "^$ADB_DIR/adb$" | head -n1 || true)"
if [[ -n "$other_adb" ]]; then
  v1="$("$ADB" version | head -n1)"; v2="$("$other_adb" version 2>/dev/null | head -n1)"
  [[ "$v1" == "$v2" ]] || warn "Hay otro adb ($other_adb, $v2) distinto del del SDK ($v1). \
Si lo usas a mano mientras corre la app, reiniciará el servidor y el emulador se desconectará. \
Mejor bórralo (brew uninstall --cask android-platform-tools) o pon \$SDK/platform-tools primero en el PATH."
fi
for tool in docker curl openssl psql; do
  command -v "$tool" >/dev/null || fail "Falta '$tool'. Consulta docs/desarrollo-local.md (requisitos)."
done
if command -v fvm >/dev/null 2>&1 && [[ -f .fvmrc ]]; then FLUTTER=(fvm flutter); else FLUTTER=(flutter); fi
command -v "${FLUTTER[0]}" >/dev/null || fail "No encuentro ${FLUTTER[0]}."
if command -v supabase >/dev/null 2>&1; then SUPA=(supabase); else SUPA=(npx -y supabase); fi
done_

# ── 1. Emulador (en segundo plano, en paralelo con el backend) ──────────────────
serial_of_running_emulator() {
  { "$ADB" devices 2>/dev/null || true; } | awk 'NR>1 && $1 ~ /^emulator-/ && $2=="device"{print $1}' | head -n1
}
SERIAL="${FLUTTER_DEVICE:-}"
[[ -n "$SERIAL" ]] || SERIAL="$(serial_of_running_emulator)"
EMU_PID=""
say "Emulador Android"
if [[ -n "$SERIAL" ]]; then
  echo "  ya conectado: $SERIAL"
else
  [[ -n "${AVD:-}" ]] || fail "No hay emulador conectado. Indica el AVD: AVD=<nombre> ./scripts/start-local.sh (lista: $EMULATOR -list-avds)"
  [[ -x "$EMULATOR" ]] || fail "No encuentro el emulador en $EMULATOR (define SDK=<ruta del SDK>)."
  "$EMULATOR" -list-avds 2>/dev/null | grep -qx "$AVD" || fail "No existe el AVD «$AVD». Disponibles: $("$EMULATOR" -list-avds | tr '\n' ' ')"
  AVD_INI="$HOME/.android/avd/$AVD.avd/config.ini"
  if [[ -f "$AVD_INI" ]]; then
    if grep -q 'abi.type=arm64' "$AVD_INI" && [[ "$(uname -m)" == "x86_64" ]]; then
      fail "El AVD «$AVD» es arm64 y este Mac es Intel: no arranca. Crea uno con imagen x86_64 (Google APIs)."
    fi
    if grep -q 'PlayStore.enabled=true' "$AVD_INI"; then
      fail "El AVD «$AVD» es «Google Play»: no permite root ni escribir /system. Crea uno «Google APIs»."
    fi
  fi
  if pgrep -f -- "-avd $AVD( |$)" >/dev/null 2>&1; then
    echo "  El proceso del emulador «$AVD» ya existe pero adb no lo ve: reinicio el servidor adb"
    "$ADB" kill-server >/dev/null 2>&1 || true
    "$ADB" start-server >/dev/null 2>&1
  else
    # -no-snapshot-save: no guardar al salir la pantalla en la que se quedó (navegador, app…).
    # COLD=1: además no cargar la instantánea (arranque limpio, ~1 min más).
    EMU_ARGS=(-avd "$AVD" -writable-system -no-snapshot-save -no-boot-anim -netdelay none -netspeed full)
    [[ "${COLD:-0}" == "1" ]] && EMU_ARGS+=(-no-snapshot-load)
    echo "  Arrancando $AVD en segundo plano (log: /tmp/icex-emulator.log)"
    nohup "$EMULATOR" "${EMU_ARGS[@]}" >/tmp/icex-emulator.log 2>&1 &
    EMU_PID=$!
  fi
fi

# ── 2. Docker ───────────────────────────────────────────────────────────────────
say "Docker"
if ! docker info >/dev/null 2>&1; then
  if [[ "$(uname)" == "Darwin" ]]; then
    open -a Docker || fail "No encuentro Docker Desktop. Instálalo o arráncalo a mano."
  fi
  for _ in $(seq 1 90); do docker info >/dev/null 2>&1 && break; sleep 2; done
  docker info >/dev/null 2>&1 || fail "Docker no arranca. Ábrelo a mano y repite el script."
fi
done_

# ── 3. Entrada de hosts para el IdP de pruebas ──────────────────────────────────
say "Nombre del IdP en /etc/hosts"
if ! grep -q "idp.icex-atlas.test" /etc/hosts; then
  echo "  Se añadirá 127.0.0.1 idp.icex-atlas.test (pide tu contraseña de Mac)"
  echo "127.0.0.1 idp.icex-atlas.test" | sudo tee -a /etc/hosts >/dev/null
fi
done_

# ── 4. Supabase local ───────────────────────────────────────────────────────────
say "Supabase local"
if "${SUPA[@]}" status >/dev/null 2>&1; then
  echo "  ya estaba en marcha"
else
  for port in 54321 54322; do
    if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      fail "El puerto $port está ocupado por otro proceso (¿otro proyecto de Supabase?). Páralo con 'supabase stop --project-id <otro>'."
    fi
  done
  "${SUPA[@]}" start -x studio,logflare,vector >/tmp/icex-supabase-start.log 2>&1 || {
    tail -20 /tmp/icex-supabase-start.log
    fail "supabase start ha fallado (salida completa en /tmp/icex-supabase-start.log)"
  }
  for _ in $(seq 1 60); do "${SUPA[@]}" status >/dev/null 2>&1 && break; sleep 2; done
  "${SUPA[@]}" status >/dev/null 2>&1 || fail "Supabase no responde. Espera un minuto y vuelve a ejecutar el script."
fi
# Migraciones nuevas que traiga el último pull (start solo las aplica al crear la base).
if "${SUPA[@]}" migration up >/tmp/icex-supabase-migrations.log 2>&1; then
  grep 'Applying migration' /tmp/icex-supabase-migrations.log | sed 's/^/  /' || true
else
  warn "No se aplicaron migraciones pendientes (ver /tmp/icex-supabase-migrations.log). Si persiste: supabase db reset"
fi
done_

# ── 5. IdP de pruebas, proveedor OIDC, Vault, app/env/local.json ────────────────
say "Configuración local (setup-local.sh)"
./scripts/setup-local.sh
done_

# ── 6. Esperar al emulador ──────────────────────────────────────────────────────
say "Esperando al emulador"
if [[ -z "$SERIAL" ]]; then
  for _ in $(seq 1 120); do
    SERIAL="$(serial_of_running_emulator)"
    [[ -n "$SERIAL" ]] && break
    if [[ -n "$EMU_PID" ]] && ! kill -0 "$EMU_PID" 2>/dev/null; then
      tail -15 /tmp/icex-emulator.log
      fail "El emulador se ha cerrado al arrancar (log completo: /tmp/icex-emulator.log). Prueba COLD=1."
    fi
    sleep 2
  done
  [[ -n "$SERIAL" ]] || fail "El emulador no aparece en adb tras 4 min. Revisa /tmp/icex-emulator.log o prueba COLD=1."
fi
export ANDROID_SERIAL="$SERIAL"
sh_() { "$ADB" -s "$SERIAL" shell "$@" 2>/dev/null | tr -d '\r'; }
for _ in $(seq 1 150); do
  [[ "$(sh_ getprop sys.boot_completed)" == "1" && "$(sh_ getprop init.svc.bootanim)" != "running" ]] \
    && sh_ pm path android | grep -q '^package:' && break
  sleep 2
done
sh_ pm path android | grep -q '^package:' || fail "El emulador no termina de arrancar (gestor de paquetes no listo). Prueba COLD=1."
# Pantalla limpia: fuera el navegador restaurado por Quick Boot y la app anterior; desbloquear.
sh_ am force-stop com.android.chrome >/dev/null || true
sh_ am force-stop es.icexalumni.atlas >/dev/null || true
sh_ wm dismiss-keyguard >/dev/null || true
sh_ input keyevent KEYCODE_HOME >/dev/null || true
echo "  $SERIAL listo"
done_

# ── 7. Puertos, nombre del IdP y certificado en el emulador ─────────────────────
say "Puertos y certificado (android-dev.sh)"
./scripts/android-dev.sh
done_

# ── 8. Java para Gradle ─────────────────────────────────────────────────────────
say "Java para Gradle"
if ! grep -q '^org.gradle.java.home' "$HOME/.gradle/gradle.properties" 2>/dev/null; then
  JH="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
  [[ -n "$JH" ]] || fail "No hay Java 17. Instálalo con: brew install --cask temurin@17"
  mkdir -p "$HOME/.gradle"
  echo "org.gradle.java.home=$JH" >> "$HOME/.gradle/gradle.properties"
  echo "  configurado: $JH"
fi
done_

# ── 9. Comprobación final ───────────────────────────────────────────────────────
say "Comprobación final"
reverse="$("$ADB" -s "$SERIAL" reverse --list 2>/dev/null)"
grep -q 'tcp:54321' <<<"$reverse" && grep -q 'tcp:9010' <<<"$reverse" \
  || fail "Los puertos del emulador no están redirigidos (adb reverse). Repite: ./scripts/android-dev.sh"
curl -sf --noproxy '*' --max-time 5 "http://127.0.0.1:54321/auth/v1/health" -H "apikey: $(sed -nE 's/.*"SUPABASE_ANON_KEY": "([^"]+)".*/\1/p' app/env/local.json)" >/dev/null \
  || fail "Supabase Auth no responde en 127.0.0.1:54321."
echo "  adb reverse 54321/9010 activo, Auth responde"
done_
printf '\nTodo listo en %ss.\n' "$((SECONDS - T0))"

# ── 10. Flutter ─────────────────────────────────────────────────────────────────
say "App"
if [[ "${NO_RUN:-0}" == "1" ]]; then
  echo "  NO_RUN=1: backend y emulador listos. Lanza la app con F5 en VS Code o con:"
  echo "  cd app && ${FLUTTER[*]} run -d $SERIAL --dart-define-from-file=env/local.json"
  exit 0
fi
cd app
"${FLUTTER[@]}" pub get >/dev/null
echo "  La primera compilación con Gradle tarda varios minutos; las siguientes, segundos."
exec "${FLUTTER[@]}" run -d "$SERIAL" --dart-define-from-file=env/local.json
