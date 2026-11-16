#!/usr/bin/env bash
# Genera (una vez) la CA local de desarrollo y el certificado TLS del IdP de pruebas.
# Solo para desarrollo/CI: docker/certs/ está en .gitignore.
set -euo pipefail
cd "$(dirname "$0")/../docker"
mkdir -p certs && cd certs
[[ -f server.crt ]] && { echo "✓ Certificados de desarrollo ya existen (docker/certs)"; exit 0; }
openssl req -x509 -newkey rsa:2048 -nodes -days 825 -keyout dev-ca.key -out dev-ca.crt \
  -subj "/CN=ICEX Atlas DEV CA (solo desarrollo)" >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -keyout server.key -out server.csr -subj "/CN=idp.icex-atlas.test" >/dev/null 2>&1
printf "subjectAltName=DNS:idp.icex-atlas.test,DNS:host.docker.internal,DNS:localhost,IP:127.0.0.1,IP:10.0.2.2\nextendedKeyUsage=serverAuth\n" > san.ext
openssl x509 -req -in server.csr -CA dev-ca.crt -CAkey dev-ca.key -CAcreateserial -days 825 -out server.crt -extfile san.ext >/dev/null 2>&1
chmod 644 server.key
rm -f server.csr san.ext
echo "✓ CA de desarrollo creada en docker/certs/dev-ca.crt"
