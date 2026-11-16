# Plan de trabajo — ICEX Atlas MVP

Fecha de inicio: 16/11/2026 · Equipo: desarrollo autónomo (Flutter + Supabase)

## Alcance y escala
- Escala de diseño **actualizada por producto** (16/11/2026): **1.000 socios al arrancar y tope de 5.000**.
  Sustituye a la cifra original (10.000 → 100.000). Ver `decisiones.md` (D-001).
- App móvil iOS/Android (Flutter 3.47.9, estable N‑1), panel admin web (Flutter web), backend 100 % Supabase.

## Referencia visual
Mockup `https://icex-alumni-atlas.lovable.app/` revisado el 16/11/2026:
- Paleta: primario rojo `oklch(52% .21 27)` ≈ `#C8102E`, acento amarillo `oklch(84% .17 88)` ≈ `#F6C200`,
  fondo cálido `#F8F5F2`, bordes `#E8E4E0`, texto `#2A2522`.
- Fases: Fase 0 gris `#8C857F`, Fase I ámbar `#D98A2B`, Fase II naranja-rojo `#D2522E`, ACTIVO rojo primario (relleno).
- Tipografías: **Sora** (títulos) y **DM Sans** (texto). Radio 12 px. Franja superior roja/amarilla/roja.
- Navegación móvil (según el prompt): Inicio · Red · Mapa · Mensajes · Orientador; avatar/Perfil y Novedades arriba.

## Fases (cada una termina en verde: analyze, tests, `supabase db reset`, `supabase test db`, `deno test`)
1. **Fundaciones** — monorepo, FVM, linters estrictos, Supabase local, OIDC de pruebas en Docker, CI, docs.
2. **Esquema y seguridad** — esquemas por módulo, tablas, índices, triggers de contadores, RLS, pgTAP, seed.
3. **Auth** — proveedor `custom:icex-alumni`, hooks (before-user-created + custom access token), acceso denegado, sesión, cron de revocación.
4. **Perfil y Red** — perfil, trayectoria, seguir, directorio (pg_trgm), sugerencias.
5. **Feed y Novedades** — publicar (texto/foto/oferta), recomendar, comentar, compartir, `get_feed` keyset, Storage.
6. **Mensajería** — `send_message` idempotente, Realtime Broadcast privado, Drift offline, leídos, deep link.
7. **Notificaciones** — pgmq + pg_cron + Edge Function, FCM (mock local), centro y preferencias.
8. **Mapa y Clubs** — PostGIS, clusters por zoom en SQL, clubs y eventos con inscripción.
9. **Orientador** — Edge Function, proveedor IA intercambiable con mock, pgvector, límites, purga 30 días.
10. **Admin, RGPD y pulido** — panel admin, moderación, exportación/borrado, accesibilidad, golden tests.
11. **Release** — Fastlane, runbook, PARADAS_HUMANAS.

## Contrato app ↔ backend
La app **solo** usa el esquema `api` de la Data API (funciones RPC `security invoker` salvo excepciones documentadas),
Storage, Realtime (canales privados) y Edge Functions. Los esquemas de módulo no se exponen.
