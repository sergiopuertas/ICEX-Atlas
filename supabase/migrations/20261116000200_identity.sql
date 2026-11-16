-- =============================================================================
-- ICEX Atlas · 0200 · identity: socios verificados, roles y hooks de Auth
-- =============================================================================

create type identity.member_status as enum ('active', 'suspended', 'revoked');
create type identity.member_role as enum ('socio', 'moderador', 'admin');

create table identity.members (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  wp_subject   text unique,                       -- `sub` del IdP WordPress
  status       identity.member_status not null default 'active',
  role         identity.member_role not null default 'socio',
  verified_at  timestamptz not null default now(),
  revoked_at   timestamptz,
  last_seen_at timestamptz,                       -- heartbeat de la app (push solo si no está conectado)
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
comment on table identity.members is 'Socios verificados de ICEX Alumni. Fuente de verdad del acceso (RLS).';
create index members_status_idx on identity.members (status) where status <> 'active';

create trigger members_touch before update on identity.members
  for each row execute function util.touch_updated_at();

alter table identity.members enable row level security;

-- -----------------------------------------------------------------------------
-- Helpers de autorización. security definer para no depender de RLS de members y
-- evitar recursión; `stable` + envolverlos en (select ...) en las políticas hace
-- que Postgres los evalúe una sola vez por sentencia (initPlan).
-- -----------------------------------------------------------------------------
create or replace function identity.is_member()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from identity.members m
    where m.user_id = (select auth.uid()) and m.status = 'active'
  );
$$;

create or replace function identity.is_member_id(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from identity.members m where m.user_id = p_user and m.status = 'active');
$$;

create or replace function identity.has_role(p_role identity.member_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from identity.members m
    where m.user_id = (select auth.uid())
      and m.status = 'active'
      and (m.role = p_role or m.role = 'admin')   -- admin hereda todo
  );
$$;

create or replace function identity.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$ select identity.has_role('admin'); $$;

create or replace function identity.is_moderator()
returns boolean language sql stable security definer set search_path = ''
as $$ select identity.has_role('moderador'); $$;

-- Exige membresía o lanza 42501 (para funciones RPC).
create or replace function identity.require_member()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null or not identity.is_member_id(v_uid) then
    raise exception 'Acceso solo para socios verificados de ICEX Alumni'
      using errcode = '42501';
  end if;
  return v_uid;
end;
$$;

grant execute on function identity.is_member(), identity.is_member_id(uuid), identity.has_role(identity.member_role),
  identity.is_admin(), identity.is_moderator(), identity.require_member() to authenticated, service_role;

-- RLS de members: cada socio ve su propia fila; admins ven todas; solo admins/servicio modifican.
create policy members_select_self on identity.members for select to authenticated
  using (user_id = (select auth.uid()) or (select identity.is_admin()));
create policy members_admin_update on identity.members for update to authenticated
  using ((select identity.is_admin())) with check ((select identity.is_admin()));
grant select, update on identity.members to authenticated;
grant all on identity.members to service_role;

-- -----------------------------------------------------------------------------
-- Hook: Before User Created. Rechaza el alta si el IdP no certifica la membresía.
-- Con el proveedor custom:icex-alumni, los claims del ID token llegan en
-- user.user_metadata.custom_claims (y en algunos casos en la raíz de user_metadata).
-- -----------------------------------------------------------------------------
create or replace function identity.claim_verified(p_meta jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    (p_meta -> 'custom_claims' ->> 'icex_member_verified')::boolean,
    (p_meta ->> 'icex_member_verified')::boolean,
    false);
$$;

create or replace function identity.before_user_created(event jsonb)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_meta jsonb := coalesce(event -> 'user' -> 'user_metadata', '{}'::jsonb);
  v_provider text := coalesce(event -> 'user' -> 'app_metadata' ->> 'provider', '');
begin
  if v_provider = 'custom:icex-alumni' and identity.claim_verified(v_meta) then
    return '{}'::jsonb;
  end if;
  return jsonb_build_object('error', jsonb_build_object(
    'http_code', 403,
    'message', 'icex_member_not_verified'));
end;
$$;

grant execute on function identity.before_user_created(jsonb) to supabase_auth_admin;
grant execute on function identity.claim_verified(jsonb) to supabase_auth_admin;
revoke execute on function identity.before_user_created(jsonb) from authenticated, anon, public;

-- Alta en members cuando se crea el usuario de Auth (ya validado por el hook).
create or replace function identity.on_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if identity.claim_verified(new.raw_user_meta_data) then
    insert into identity.members (user_id, wp_subject, status)
    values (new.id, coalesce(new.raw_user_meta_data ->> 'sub', new.raw_user_meta_data -> 'custom_claims' ->> 'sub'), 'active')
    on conflict (user_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function identity.on_auth_user_created();

-- -----------------------------------------------------------------------------
-- Hook: Custom Access Token. Se ejecuta en cada login y refresh.
--  * Socio activo → añade user_role e icex_member al JWT.
--  * Sin membresía activa → error: no se emite token (revocación efectiva al refrescar).
-- -----------------------------------------------------------------------------
create or replace function identity.custom_access_token(event jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_uid uuid := (event ->> 'user_id')::uuid;
  v_claims jsonb := coalesce(event -> 'claims', '{}'::jsonb);
  v_role identity.member_role;
begin
  select m.role into v_role
  from identity.members m
  where m.user_id = v_uid and m.status = 'active';

  if v_role is null then
    return jsonb_build_object('error', jsonb_build_object(
      'http_code', 403, 'message', 'icex_member_not_active'));
  end if;

  v_claims := jsonb_set(v_claims, '{user_role}', to_jsonb(v_role::text));
  v_claims := jsonb_set(v_claims, '{icex_member}', 'true'::jsonb);
  return jsonb_build_object('claims', v_claims);
end;
$$;

grant usage on schema identity to supabase_auth_admin;
grant execute on function identity.custom_access_token(jsonb) to supabase_auth_admin;
revoke execute on function identity.custom_access_token(jsonb) from authenticated, anon, public;
grant select on identity.members to supabase_auth_admin;
create policy members_auth_admin_read on identity.members for select to supabase_auth_admin using (true);

-- -----------------------------------------------------------------------------
-- Bajas: revoca sesiones de quien deja de ser socio (lo invoca el cron diario
-- tras consultar WordPress, ver supabase/functions/membership-sync).
-- -----------------------------------------------------------------------------
create or replace function identity.revoke_member(p_user uuid, p_reason text default 'baja')
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update identity.members
     set status = 'revoked', revoked_at = now()
   where user_id = p_user and status <> 'revoked';
  delete from auth.sessions where user_id = p_user;          -- cascada a refresh_tokens
  raise log 'identity.revoke_member user=% reason=%', p_user, p_reason;  -- sin datos personales
end;
$$;
revoke execute on function identity.revoke_member(uuid, text) from public, authenticated, anon;
grant execute on function identity.revoke_member(uuid, text) to service_role;

create or replace function identity.reactivate_member(p_user uuid)
returns void language sql security definer set search_path = ''
as $$ update identity.members set status = 'active', revoked_at = null where user_id = p_user; $$;
revoke execute on function identity.reactivate_member(uuid) from public, authenticated, anon;
grant execute on function identity.reactivate_member(uuid) to service_role;
