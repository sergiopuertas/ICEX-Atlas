-- =============================================================================
-- ICEX Atlas · 0300 · profiles: perfil, trayectoria, fase, promoción, privacidad
-- =============================================================================

create type profiles.fase as enum ('fase_0', 'fase_1', 'fase_2', 'activo');
-- Visibilidad por campo: todos los socios / solo mis seguidores / solo yo.
create type profiles.visibilidad as enum ('socios', 'seguidores', 'solo_yo');

create table profiles.profiles (
  user_id             uuid primary key references identity.members (user_id) on delete cascade,
  slug                text not null unique check (slug ~ '^[a-z0-9-]{3,80}$'),
  nombre              text not null check (char_length(nombre) between 2 and 120),
  cargo               text check (char_length(cargo) <= 140),
  empresa             text check (char_length(empresa) <= 140),
  fase                profiles.fase not null default 'activo',
  promocion           smallint not null check (promocion between 1 and 99),
  pais                text check (char_length(pais) <= 80),
  pais_code           char(2),
  ciudad              text check (char_length(ciudad) <= 80),
  sector              text check (char_length(sector) <= 80),
  -- Ubicación a nivel de ciudad (nunca la posición exacta del dispositivo).
  ubicacion           extensions.geography(point, 4326),
  foto_path           text,                               -- ruta en Storage bucket `avatars`
  bio                 text check (char_length(bio) <= 1200),
  visibilidad         jsonb not null default
                        '{"cargo":"socios","empresa":"socios","ciudad":"socios","ubicacion":"socios","bio":"socios","trayectoria":"socios"}'::jsonb,
  acepta_sugerencias  boolean not null default true,      -- aparecer en "Personas que quizá conozcas" y Orientador
  en_el_exterior      boolean generated always as (pais_code is not null and pais_code <> 'ES') stored,
  seguidores_count    integer not null default 0 check (seguidores_count >= 0),
  siguiendo_count     integer not null default 0 check (siguiendo_count >= 0),
  posts_count         integer not null default 0 check (posts_count >= 0),
  busqueda            text generated always as (
                        util.normalize(nombre || ' ' || coalesce(empresa, '') || ' ' || coalesce(ciudad, '') || ' '
                          || coalesce(cargo, '') || ' ' || coalesce(pais, '') || ' ' || promocion::text || 'ª')
                      ) stored,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

comment on column profiles.profiles.visibilidad is
  'Visibilidad por campo: {"cargo"|"empresa"|"ciudad"|"ubicacion"|"bio"|"trayectoria": "socios"|"seguidores"|"solo_yo"}';

create index profiles_busqueda_trgm_idx on profiles.profiles using gin (busqueda extensions.gin_trgm_ops);
create index profiles_promocion_idx on profiles.profiles (promocion, nombre, user_id);
create index profiles_fase_idx on profiles.profiles (fase, nombre, user_id);
create index profiles_nombre_idx on profiles.profiles (nombre, user_id);
create index profiles_ubicacion_gix on profiles.profiles using gist (ubicacion);
create index profiles_exterior_idx on profiles.profiles (nombre, user_id) where en_el_exterior;

create trigger profiles_touch before update on profiles.profiles
  for each row execute function util.touch_updated_at();

create table profiles.experiences (
  id          uuid primary key default util.uuid_v7(),
  user_id     uuid not null references profiles.profiles (user_id) on delete cascade,
  empresa     text not null check (char_length(empresa) between 1 and 140),
  cargo       text not null check (char_length(cargo) between 1 and 140),
  desde       date not null,
  hasta       date,
  created_at  timestamptz not null default now(),
  check (hasta is null or hasta >= desde)
);
create index experiences_user_idx on profiles.experiences (user_id, desde desc);

alter table profiles.profiles enable row level security;
alter table profiles.experiences enable row level security;

-- Lectura de filas: cualquier socio activo. El enmascarado por campo se aplica en
-- profiles.card()/profiles.detail() (la tabla no está expuesta por la Data API).
create policy profiles_select_members on profiles.profiles for select to authenticated
  using ((select identity.is_member()));
create policy profiles_update_own on profiles.profiles for update to authenticated
  using (user_id = (select auth.uid()) and (select identity.is_member()))
  with check (user_id = (select auth.uid()));
create policy profiles_admin_all on profiles.profiles for all to authenticated
  using ((select identity.is_admin())) with check ((select identity.is_admin()));

create policy experiences_select_members on profiles.experiences for select to authenticated
  using ((select identity.is_member()));
create policy experiences_write_own on profiles.experiences for all to authenticated
  using (user_id = (select auth.uid()) and (select identity.is_member()))
  with check (user_id = (select auth.uid()) and (select identity.is_member()));

grant select, update (cargo, empresa, fase, pais, pais_code, ciudad, sector, ubicacion, foto_path, bio,
  visibilidad, acepta_sugerencias, nombre) on profiles.profiles to authenticated;
grant select, insert, update, delete on profiles.experiences to authenticated;
grant all on profiles.profiles, profiles.experiences to service_role;

-- Perfil inicial al darse de alta un socio, con los datos que envía el IdP.
create or replace function profiles.slugify(p_name text, p_user uuid)
returns text language sql immutable set search_path = ''
as $$
  select left(trim(both '-' from regexp_replace(util.normalize(p_name), '[^a-z0-9]+', '-', 'g')), 60)
         || '-' || left(replace(p_user::text, '-', ''), 8);
$$;

create or replace function profiles.on_member_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta jsonb;
  v_name text;
  v_promo int;
begin
  select coalesce(u.raw_user_meta_data, '{}'::jsonb) into v_meta from auth.users u where u.id = new.user_id;
  v_name := coalesce(nullif(v_meta ->> 'name', ''), nullif(v_meta -> 'custom_claims' ->> 'name', ''), 'Socio ICEX Alumni');
  v_promo := coalesce((v_meta -> 'custom_claims' ->> 'icex_promocion')::int, (v_meta ->> 'icex_promocion')::int, 1);
  insert into profiles.profiles (user_id, slug, nombre, promocion, fase)
  values (new.user_id, profiles.slugify(v_name, new.user_id), v_name, least(greatest(v_promo, 1), 99),
          coalesce((v_meta -> 'custom_claims' ->> 'icex_fase')::profiles.fase, 'activo'))
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_member_created after insert on identity.members
  for each row execute function profiles.on_member_created();

-- -----------------------------------------------------------------------------
-- Interfaz pública del módulo: tarjeta/detalle con privacidad aplicada.
-- p_viewer_follows: si quien mira sigue al dueño (lo calcula el llamador vía social).
-- -----------------------------------------------------------------------------
create or replace function profiles.can_see(p_vis jsonb, p_field text, p_is_owner boolean, p_viewer_follows boolean)
returns boolean language sql immutable set search_path = ''
as $$
  select p_is_owner or case coalesce(p_vis ->> p_field, 'socios')
    when 'socios' then true
    when 'seguidores' then p_viewer_follows
    else false end;
$$;

create or replace function profiles.card(p profiles.profiles, p_viewer uuid, p_viewer_follows boolean)
returns jsonb language sql stable set search_path = ''
as $$
  select jsonb_build_object(
    'user_id', p.user_id,
    'slug', p.slug,
    'nombre', p.nombre,
    'cargo', case when profiles.can_see(p.visibilidad, 'cargo', p.user_id = p_viewer, p_viewer_follows) then p.cargo end,
    'empresa', case when profiles.can_see(p.visibilidad, 'empresa', p.user_id = p_viewer, p_viewer_follows) then p.empresa end,
    'fase', p.fase,
    'promocion', p.promocion,
    'pais', p.pais,
    'ciudad', case when profiles.can_see(p.visibilidad, 'ciudad', p.user_id = p_viewer, p_viewer_follows) then p.ciudad end,
    'sector', p.sector,
    'foto_path', p.foto_path,
    'seguidores_count', p.seguidores_count,
    'siguiendo_count', p.siguiendo_count
  );
$$;

grant execute on all functions in schema profiles to authenticated, service_role;
