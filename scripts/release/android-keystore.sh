#!/usr/bin/env bash
# Crea (una sola vez) la clave de firma de Android de la beta y muestra lo que hay que pegar
# en los secretos del entorno «staging» de GitHub. GUARDA el .jks y las contraseñas en un
# gestor de contraseñas: sin esa clave no se pueden publicar actualizaciones de la app.
#
# Uso: ./scripts/release/android-keystore.sh [fichero.jks]
set -euo pipefail
OUT="${1:-$HOME/icex-atlas-upload.jks}"
ALIAS="icex-atlas"
command -v keytool >/dev/null || { echo "✗ Falta keytool (viene con Java 17: brew install --cask temurin@17)"; exit 1; }
[[ -e "$OUT" ]] && { echo "✗ $OUT ya existe. No la sobrescribo: perderías la firma de la app."; exit 1; }
read -r -s -p "Contraseña para la clave (mín. 6 caracteres): " PASS; echo
keytool -genkeypair -v -keystore "$OUT" -alias "$ALIAS" -keyalg RSA -keysize 4096 -validity 10000 \
  -storepass "$PASS" -keypass "$PASS" -dname "CN=ICEX Atlas, O=ICEX Alumni, C=ES" >/dev/null
echo
echo "✓ Clave creada en $OUT"
echo
echo "Secretos del entorno «staging» en GitHub (Settings → Environments → staging):"
echo "  ANDROID_KEYSTORE_BASE64  = (copiado al portapapeles si tienes pbcopy; si no, el contenido de abajo)"
echo "  ANDROID_KEYSTORE_PASSWORD = la contraseña que acabas de escribir"
echo "  ANDROID_KEY_ALIAS        = $ALIAS"
echo "  ANDROID_KEY_PASSWORD     = la misma contraseña"
if command -v pbcopy >/dev/null; then base64 < "$OUT" | tr -d '\n' | pbcopy; else base64 < "$OUT" | tr -d '\n'; echo; fi
