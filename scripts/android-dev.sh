#!/usr/bin/env bash
# Prepara un emulador Android para usar la Supabase local y el IdP de pruebas.
#
# Por qué hace falta: el login OIDC pasa por http://127.0.0.1:54321 (Supabase) y
# https://idp.icex-atlas.test:9010 (IdP). Dentro del emulador, 127.0.0.1 es el propio emulador:
#   1) el nombre idp.icex-atlas.test debe resolver a 127.0.0.1 dentro del emulador (fichero hosts);
#   2) el navegador del emulador debe confiar en la CA de desarrollo (docker/certs/dev-ca.crt);
#   3) `adb reverse` lleva los puertos 54321 y 9010 del emulador a tu máquina.
# El orden importa: `adb root` reinicia adbd y BORRA los `adb reverse` hechos antes.
#
# Requisitos: un AVD con imagen «Google APIs» (NO «Google Play», que no permite root),
# arrancado con almacenamiento de sistema escribible:
#   emulator -avd <nombre> -writable-system
# `adb reverse` se pierde al reiniciar el emulador: vuelve a ejecutar este script.
# Con varios dispositivos conectados, indica cuál: ANDROID_SERIAL=emulator-5554 ./scripts/android-dev.sh
set -euo pipefail
cd "$(dirname "$0")/.."

command -v adb >/dev/null || { echo "✗ No encuentro adb (Android SDK platform-tools en el PATH)"; exit 1; }
if [[ -z "${ANDROID_SERIAL:-}" ]]; then
  ANDROID_SERIAL="$(adb devices | awk 'NR>1 && $2=="device"{print $1}' | grep '^emulator-' | head -n1 || true)"
  [[ -n "$ANDROID_SERIAL" ]] || ANDROID_SERIAL="$(adb devices | awk 'NR>1 && $2=="device"{print $1; exit}')"
fi
[[ -n "$ANDROID_SERIAL" ]] || { echo "✗ No hay ningún emulador/dispositivo conectado"; exit 1; }
export ANDROID_SERIAL
shell() { adb shell "$@" 2>/dev/null | tr -d '\r'; }
wait_device() {
  adb wait-for-device
  for _ in $(seq 1 30); do [[ "$(shell getprop sys.boot_completed)" == "1" ]] && return 0; sleep 1; done
}
echo "  dispositivo: $ANDROID_SERIAL"

CA="docker/certs/dev-ca.crt"
[[ -f "$CA" ]] || ./scripts/dev-certs.sh >/dev/null
CA_HASH="$(openssl x509 -inform PEM -subject_hash_old -noout -in "$CA")"
USER_CA="/data/misc/user/0/cacerts-added/${CA_HASH}.0"

need_hosts=1; need_ca=1
shell grep -q idp.icex-atlas.test /system/etc/hosts && need_hosts=0
[[ "$(shell "test -f $USER_CA && echo yes")" == "yes" ]] && need_ca=0

if (( need_hosts || need_ca )); then
  echo "→ Acceso root al emulador"
  if [[ "$(shell id -u)" != "0" ]]; then
    adb root >/dev/null 2>&1 || true
    wait_device
  fi
  [[ "$(shell id -u)" == "0" ]] || {
    echo "✗ El emulador no permite root. Usa una imagen «Google APIs» (no «Google Play»)."; exit 1; }
fi

echo "→ idp.icex-atlas.test → 127.0.0.1 dentro del emulador"
if (( need_hosts )); then
  out="$(adb remount 2>&1 || true)"
  if grep -qi 'reboot' <<<"$out"; then
    echo "  Primera vez: el emulador necesita reiniciarse para escribir en /system (≈1 min)…"
    adb reboot
    wait_device
    adb root >/dev/null 2>&1 || true
    wait_device
    out="$(adb remount 2>&1 || true)"
  fi
  if ! grep -qiE 'remount succeeded|remounted' <<<"$out"; then
    echo "✗ No se puede escribir en /system. Arranca el emulador con: emulator -avd <nombre> -writable-system"
    echo "  (salida de adb remount: $out)"
    exit 1
  fi
  shell "echo '127.0.0.1 idp.icex-atlas.test' >> /system/etc/hosts"
  shell grep -q idp.icex-atlas.test /system/etc/hosts || { echo "✗ No se pudo escribir /system/etc/hosts"; exit 1; }
  echo "  añadido"
else
  echo "  ya estaba"
fi

echo "→ CA de desarrollo instalada como certificado de usuario (Chrome y la app en debug confían en ella)"
if (( need_ca )); then
  adb push "$CA" "/data/local/tmp/${CA_HASH}.0" >/dev/null
  shell "mkdir -p /data/misc/user/0/cacerts-added && cp /data/local/tmp/${CA_HASH}.0 $USER_CA \
    && chown system:system $USER_CA && chmod 644 $USER_CA && (restorecon $USER_CA || true) \
    && rm /data/local/tmp/${CA_HASH}.0"
  if [[ "$(shell "test -f $USER_CA && echo yes")" == "yes" ]]; then
    echo "  instalada (${CA_HASH}.0)"
  else
    adb push "$CA" /sdcard/Download/icex-atlas-dev-ca.crt >/dev/null
    cat <<'TXT'
  ⚠ No se pudo instalar sola. Hazlo una vez a mano en el emulador:
    Ajustes → Seguridad y privacidad → Más ajustes de seguridad → Cifrado y credenciales
    → Instalar un certificado → Certificado de CA → Descargas → icex-atlas-dev-ca.crt
TXT
  fi
else
  echo "  ya estaba"
fi

# Chrome sin pantallas de bienvenida (aparecían al abrir el login: «Welcome to Chrome»…).
shell "echo '_ --disable-fre --no-default-browser-check --no-first-run' > /data/local/tmp/chrome-command-line" || true
shell am set-debug-app --persistent com.android.chrome >/dev/null || true

echo "→ Puertos del emulador → tu máquina (Supabase 54321, IdP 9010)"
adb reverse tcp:54321 tcp:54321 >/dev/null
adb reverse tcp:9010 tcp:9010 >/dev/null
adb reverse --list | grep -q 'tcp:54321' || { echo "✗ adb reverse no ha quedado activo"; exit 1; }
echo "  ok"
echo "✓ Emulador listo."
