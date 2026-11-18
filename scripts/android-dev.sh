#!/usr/bin/env bash
# Prepara un emulador Android para usar la Supabase local y el IdP de pruebas.
#
# Por qué hace falta: el login OIDC pasa por http://127.0.0.1:54321 (Supabase) y
# https://idp.icex-atlas.test:9010 (IdP). Dentro del emulador, 127.0.0.1 es el propio emulador:
#   1) `adb reverse` lleva los puertos 54321 y 9010 del emulador a tu máquina;
#   2) el nombre idp.icex-atlas.test debe resolver a 127.0.0.1 dentro del emulador (fichero hosts);
#   3) el navegador del emulador debe confiar en la CA de desarrollo (docker/certs/dev-ca.crt).
#
# Requisitos: un AVD con imagen «Google APIs» (NO «Google Play», que no permite root),
# arrancado con almacenamiento de sistema escribible:
#   emulator -avd <nombre> -writable-system
# `adb reverse` se pierde al reiniciar el emulador: vuelve a ejecutar este script.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v adb >/dev/null || { echo "✗ No encuentro adb (Android SDK platform-tools en el PATH)"; exit 1; }
adb get-state >/dev/null 2>&1 || { echo "✗ No hay ningún emulador/dispositivo conectado"; exit 1; }

echo "→ Puertos del emulador → tu máquina (Supabase 54321, IdP 9010)"
adb reverse tcp:54321 tcp:54321
adb reverse tcp:9010 tcp:9010

echo "→ idp.icex-atlas.test → 127.0.0.1 dentro del emulador"
if adb shell grep -q idp.icex-atlas.test /system/etc/hosts 2>/dev/null; then
  echo "  ya estaba"
else
  adb root >/dev/null && sleep 2
  if ! adb remount >/dev/null 2>&1; then
    echo "✗ No se puede escribir en /system. Usa una imagen «Google APIs» y arranca con: emulator -avd <nombre> -writable-system"
    echo "  (la primera vez, tras 'adb remount' puede pedir 'adb reboot' y volver a ejecutar este script)"
    exit 1
  fi
  adb shell "echo '127.0.0.1 idp.icex-atlas.test' >> /system/etc/hosts"
  echo "  añadido"
fi

echo "→ CA de desarrollo copiada a Descargas del emulador"
adb push docker/certs/dev-ca.crt /sdcard/Download/icex-atlas-dev-ca.crt >/dev/null
cat <<'TXT'

Último paso (solo la primera vez), en el emulador:
  Ajustes → Seguridad y privacidad → Más ajustes de seguridad → Cifrado y credenciales
  → Instalar un certificado → Certificado de CA → Descargas → icex-atlas-dev-ca.crt
(La app en modo debug confía en certificados de usuario; las builds de release, no.)

✓ Listo. Lanza «App · local» en VS Code con el emulador seleccionado.
TXT
