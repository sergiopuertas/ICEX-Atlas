# ICEX Atlas

Red social profesional privada de **ICEX Alumni** para iOS y Android. Solo entran socios verificados con su cuenta
de la web de la asociación.

- **App:** Flutter 3.47.9 (N-1, FVM) · Riverpod · go_router · Drift · FCM · Sentry
- **Backend:** Supabase (PostgreSQL 17 con RLS, Auth OIDC, Realtime, Storage, Edge Functions, pgmq, pg_cron, PostGIS, pg_trgm, pgvector)
- **Panel admin:** Flutter web (`admin/`)

| Documento | Para qué |
|---|---|
| [`docs/arquitectura.md`](docs/arquitectura.md) | Arquitectura, módulos, flujos y rendimiento medido |
| [`docs/decisiones.md`](docs/decisiones.md) | Decisiones técnicas (D-001…) y su justificación |
| [`docs/runbook.md`](docs/runbook.md) | Despliegue a producción, rotación de claves, restauración de copias |
| [`docs/PARADAS_HUMANAS.md`](docs/PARADAS_HUMANAS.md) | Lo que debe hacer una persona: cuentas, contratos, WordPress, tiendas |
| [`wordpress/README.md`](wordpress/README.md) | WordPress como proveedor OpenID Connect y endpoint de membresías |

## Arranque en local

Requisitos: Docker, [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started),
Flutter 3.47.9 (`fvm install`), Deno 2 y Node 22 (solo para los E2E).
Una sola vez, añade el IdP de pruebas a tu `/etc/hosts`:
`echo "127.0.0.1 idp.icex-atlas.test" | sudo tee -a /etc/hosts`.

```bash
supabase start                      # Postgres, Auth, Realtime, Storage, Edge Functions (aplica migraciones + seed)
./scripts/setup-local.sh            # IdP OIDC de pruebas, proveedor custom:icex-alumni, Vault, app/env/local.json
cd app && flutter pub get
flutter run --dart-define-from-file=env/local.json
```

Usuarios de prueba (se eligen con un botón en la pantalla del IdP simulado, sin contraseña): `ana` y `javier` (socios), `laura` (admin), `nueva` (alta nueva)
y `pedro` (**no socio**: ve la pantalla de acceso denegado). Los datos semilla son ficticios: 640 perfiles,
publicaciones, clubs y conversaciones.

> **Simulador o emulador.** El login abre `https://idp.icex-atlas.test:9010`, firmado por una CA de desarrollo
> (`docker/certs/dev-ca.crt`). Instala esa CA en el simulador o emulador y, en Android, apunta el nombre a la IP del
> host (`10.0.2.2`) y usa `SUPABASE_URL=http://10.0.2.2:54321`. En el simulador de iOS basta con instalar la CA
> (`xcrun simctl keychain booted add-root-cert docker/certs/dev-ca.crt`).

Panel admin: `cd admin && flutter run -d chrome --dart-define-from-file=../app/env/local.json` (entra como `laura`).
Supabase Studio: http://127.0.0.1:54323.

## Tests

```bash
supabase test db                                    # pgTAP: RLS (positivo y negativo), API, hooks, colas
(cd supabase/functions && deno lint && deno check --no-lock */index.ts tests/*.ts && deno test --no-lock --allow-env --allow-net tests/)
(cd app && flutter analyze --fatal-infos && flutter test --coverage && python3 ../scripts/coverage_layers.py coverage/lcov.info 80)
(cd scripts/e2e && npm ci && node --test)          # E2E: login OIDC → feed → publicar → seguir → mensaje en tiempo real
./scripts/perf.sh                                   # p95 de get_feed y search_directory (< 200 ms) + EXPLAIN ANALYZE
```

La CI (`.github/workflows/ci.yml`) ejecuta todo lo anterior, además de: comprobar que el esquema no difiere de las
migraciones, comprobar el código generado y el formato, y buscar secretos con gitleaks.

## Estructura

```
app/        App Flutter (lib/core, lib/features/<feature>/{domain,data,application,presentation}, lib/shared)
admin/      Panel de administración (Flutter web)
supabase/   config.toml, migrations/, functions/ (Edge Functions Deno), tests/ (pgTAP), seed.sql
docker/     IdP OIDC de pruebas (simula WordPress + endpoint de membresías)
wordpress/  Snippet de claims OIDC y endpoint de membresías para la web real
scripts/    setup local, E2E, rendimiento, cobertura por capas
docs/       arquitectura, decisiones, runbook, paradas humanas
```

## Seguridad

- La clave `service_role` **nunca** está en la app ni en el panel. Solo en secretos de Edge Functions y CI.
- No hay secretos en el repositorio. Las plantillas están en `.env.example`, `app/env/example.json` y
  `supabase/functions/.env.local.example`.
- RLS en todas las tablas (un test lo comprueba) y solo el esquema `api` expuesto.
