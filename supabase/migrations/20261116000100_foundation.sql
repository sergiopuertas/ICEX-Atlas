-- =============================================================================
-- ICEX Atlas · 0100 · Fundaciones: extensiones, esquemas por módulo, utilidades
-- =============================================================================
-- Principios (docs/arquitectura.md):
--   * Un esquema por módulo de dominio. Solo `api` se expone a la Data API.
--   * RLS en todas las tablas (test de CI: supabase/tests/000_rls_everywhere.test.sql).
--   * Funciones security definer solo cuando es imprescindible, con search_path = ''.

create extension if not exists postgis with schema extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;
create extension if not exists vector with schema extensions;
create extension if not exists pgmq;
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

create schema if not exists util;
create schema if not exists identity;
create schema if not exists profiles;
create schema if not exists social;
create schema if not exists clubs;
create schema if not exists feed;
create schema if not exists messaging;
create schema if not exists notifications;
create schema if not exists orientador;
create schema if not exists moderation;
create schema if not exists config;
create schema if not exists api;

comment on schema api is 'Única superficie expuesta por la Data API (PostgREST). Funciones RPC y vistas.';

-- Los roles de la API solo necesitan USAGE en los esquemas internos para que las
-- funciones security invoker de `api` puedan operar bajo RLS. No se exponen por PostgREST.
grant usage on schema util, identity, profiles, social, clubs, feed, messaging,
  notifications, orientador, moderation, config, api to authenticated, service_role;
grant usage on schema api to anon;
-- Nada en public para la API.
revoke all on schema public from anon, authenticated;

-- Privilegios por defecto: nada se concede automáticamente a anon.
alter default privileges in schema api revoke execute on functions from public;
alter default privileges in schema util revoke execute on functions from public;
alter default privileges in schema identity revoke execute on functions from public;
alter default privileges in schema profiles revoke execute on functions from public;
alter default privileges in schema social revoke execute on functions from public;
alter default privileges in schema clubs revoke execute on functions from public;
alter default privileges in schema feed revoke execute on functions from public;
alter default privileges in schema messaging revoke execute on functions from public;
alter default privileges in schema notifications revoke execute on functions from public;
alter default privileges in schema orientador revoke execute on functions from public;
alter default privileges in schema moderation revoke execute on functions from public;
alter default privileges in schema config revoke execute on functions from public;

-- -----------------------------------------------------------------------------
-- UUIDv7 — la app genera los ids (paquete `uuid` de Dart). Estas funciones solo
-- sirven de valor por defecto (seed, tareas del servidor) y para calcular límites
-- de partición. PostgreSQL 17 no trae uuidv7() nativo (llega en PG 18).
-- -----------------------------------------------------------------------------
create or replace function util.uuid_v7(p_ts timestamptz default clock_timestamp())
returns uuid
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_ms bigint := floor(extract(epoch from p_ts) * 1000);
  v_bytes bytea;
begin
  v_bytes := decode(lpad(to_hex(v_ms), 12, '0'), 'hex') || extensions.gen_random_bytes(10);
  -- versión 7
  v_bytes := set_byte(v_bytes, 6, (get_byte(v_bytes, 6) & 15) | 112);
  -- variante RFC 9562 (10xx)
  v_bytes := set_byte(v_bytes, 8, (get_byte(v_bytes, 8) & 63) | 128);
  return encode(v_bytes, 'hex')::uuid;
end;
$$;

-- Menor UUIDv7 posible para un instante: límite inferior de partición.
create or replace function util.uuid_v7_floor(p_ts timestamptz)
returns uuid
language sql
immutable
parallel safe
set search_path = ''
as $$
  select (lpad(to_hex(floor(extract(epoch from p_ts) * 1000)::bigint), 12, '0') || '00000000000000000000')::uuid;
$$;

create or replace function util.uuid_v7_time(p_id uuid)
returns timestamptz
language sql
immutable
parallel safe
set search_path = ''
as $$
  select to_timestamp(('x' || substr(replace(p_id::text, '-', ''), 1, 12))::bit(48)::bigint / 1000.0);
$$;

-- unaccent inmutable para índices trigram (búsqueda insensible a tildes).
create or replace function util.f_unaccent(text)
returns text
language sql
immutable
parallel safe
strict
set search_path = ''
as $$
  select extensions.unaccent('extensions.unaccent'::regdictionary, $1);
$$;

create or replace function util.normalize(p text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select lower(util.f_unaccent(coalesce(p, '')));
$$;

-- updated_at genérico
create or replace function util.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Cursor keyset (created_at, id) codificado como texto opaco "epoch_us|uuid".
create or replace function util.encode_cursor(p_ts timestamptz, p_id uuid)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case when p_ts is null then null
    else (floor(extract(epoch from p_ts) * 1000000))::bigint::text || '|' || p_id::text end;
$$;

create or replace function util.cursor_ts(p_cursor text)
returns timestamptz
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case when p_cursor is null or p_cursor = '' then null
    -- aritmética entera de microsegundos: sin pérdida de precisión de coma flotante
    else timestamptz 'epoch' + make_interval(secs => 0) + (split_part(p_cursor, '|', 1)::bigint * interval '1 microsecond') end;
$$;

create or replace function util.cursor_id(p_cursor text)
returns uuid
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case when p_cursor is null or p_cursor = '' then null
    else split_part(p_cursor, '|', 2)::uuid end;
$$;

grant execute on all functions in schema util to authenticated, service_role;
