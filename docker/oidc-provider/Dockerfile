# Proveedor OIDC de pruebas (solo desarrollo/CI). Imagen base de Docker Hub.
FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY server.js ./
USER node
EXPOSE 9010
HEALTHCHECK --interval=5s --timeout=3s --retries=10 CMD wget -qO- --no-check-certificate https://127.0.0.1:9010/healthz || wget -qO- http://127.0.0.1:9010/healthz || exit 1
CMD ["node", "server.js"]
