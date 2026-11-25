-- =============================================================================
-- ICEX Atlas · 20261124-0400 · Agregados en caché y sugerencias acotadas
-- Con 30.000 socios y 24 conexiones a la vez (supabase/stress/scale.py) tres endpoints
-- recorrían TODOS los perfiles en cada llamada y se comían la CPU del resto:
--  · map_clusters a zoom de continente/mundo  (p95 bajo carga ≈ 2 s)
--  · suggestions                              (≈ 0,7 s)
--  · community_stats                          (≈ 0,3 s)
-- Mapa (zoom ≤ 6) y cifras de la comunidad salen ahora de agregados precalculados cada
-- 10 minutos (pg_cron). Si la caché está vacía o caducada (>15 min) se calcula en vivo, así
-- que nunca se sirve nada incorrecto tras un `db reset` o si el cron se detiene.
-- Privacidad: una celda con UN solo socio se vuelve a comprobar en vivo (visibilidad,
-- bloqueos, baja) antes de mostrar su ficha.
-- =============================================================================

create table profiles.map_grid (
  cell_x   integer not null,             -- floor(lng / 0.25)
  cell_y   integer not null,             -- floor(lat / 0.25)
  fase     profiles.fase not null,
  n        integer not null,
  sum_lat  double precision not null,
  sum_lng  double precision not null,
  any_user uuid not null,
  primary key (cell_x, cell_y, fase)
);
create table profiles.aggregates_meta (
  id               boolean primary key default true check (id),
  community_stats  jsonb not null,
  refreshed_at     timestamptz not null default now()
);
alter table profiles.map_grid enable row level security;          -- sin políticas: solo funciones
alter table profiles.aggregates_meta enable row level security;
revoke all on profiles.map_grid, profiles.aggregates_meta from anon, authenticated;

create or replace function profiles.refresh_aggregates()
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if not pg_try_advisory_xact_lock(hashtextextended('profiles.refresh_aggregates', 0)) then
    return;   -- ya hay otro refresco en marcha
  end if;
  delete from profiles.map_grid;
  insert into profiles.map_grid (cell_x, cell_y, fase, n, sum_lat, sum_lng, any_user)
  select floor(extensions.st_x(g) / 0.25)::int, floor(extensions.st_y(g) / 0.25)::int, fase,
         count(*), sum(extensions.st_y(g)), sum(extensions.st_x(g)), any_value(user_id)
    from (select p.user_id, p.fase, p.ubicacion::extensions.geometry as g
            from profiles.profiles p
            join identity.members m on m.user_id = p.user_id and m.status = 'active'
           where p.ubicacion is not null
             and coalesce(p.visibilidad ->> 'ubicacion', 'socios') = 'socios') x
   group by 1, 2, 3;

  insert into profiles.aggregates_meta (id, community_stats, refreshed_at)
  select true, jsonb_build_object(
           'alumni', count(*),
           'activos', count(*) filter (where p.fase = 'activo'),
           'paises', count(distinct p.pais_code),
           'promociones', count(distinct p.promocion)), now()
    from profiles.profiles p
    join identity.members m on m.user_id = p.user_id and m.status = 'active'
  on conflict (id) do update set community_stats = excluded.community_stats, refreshed_at = excluded.refreshed_at;
end;
$$;
revoke execute on function profiles.refresh_aggregates() from public, anon, authenticated;
grant execute on function profiles.refresh_aggregates() to service_role;

-- Sin refresco aquí: en un `db reset` las semillas se cargan DESPUÉS de las migraciones y una
-- caché «fresca» pero vacía dejaría el mapa mundial en blanco hasta el siguiente cron. Sin
-- caché, todo se calcula en vivo hasta el primer refresco.
select cron.schedule('profiles-aggregates', '*/10 * * * *', $$select profiles.refresh_aggregates()$$);

create or replace function profiles.aggregates_fresh()
returns boolean language sql stable security definer set search_path = ''
as $$ select coalesce((select refreshed_at > now() - interval '15 minutes' from profiles.aggregates_meta), false); $$;

-- ---------------------------------------------------------- community_stats ---
create or replace function api.community_stats()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  v_override jsonb;
  v_uid uuid := identity.require_member();
begin
  v_override := config.get('community.stats_override');
  if v_override is not null and v_override <> 'null'::jsonb then
    return v_override;
  end if;
  if profiles.aggregates_fresh() then
    return (select community_stats from profiles.aggregates_meta);
  end if;
  return (select jsonb_build_object(
    'alumni', count(*),
    'activos', count(*) filter (where p.fase = 'activo'),
    'paises', count(distinct p.pais_code),
    'promociones', count(distinct p.promocion))
    from profiles.profiles p
    join identity.members m on m.user_id = p.user_id and m.status = 'active');
end;
$$;

-- -------------------------------------------------------------- map_clusters ---
create or replace function api.map_clusters(
  p_zoom int, p_west double precision, p_south double precision,
  p_east double precision, p_north double precision,
  p_fases profiles.fase[] default null, p_include_clubs boolean default true)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_zoom int := least(greatest(coalesce(p_zoom, 2), 0), 18);
  v_cell double precision := 360.0 / power(2, v_zoom) / 3.0;
  v_w double precision := greatest(p_west, -180);
  v_s double precision := greatest(p_south, -85);
  v_e double precision := least(p_east, 180);
  v_n double precision := least(p_north, 85);
  v_env extensions.geometry;
  v_blocked uuid[];
  v_clusters jsonb;
  v_clubs jsonb := '[]'::jsonb;
begin
  -- Envolvente (sin cruzar el antimeridiano; el cliente parte la vista si hace falta).
  v_env := extensions.st_makeenvelope(v_w, v_s, v_e, v_n, 4326);
  select coalesce(array_agg(b), '{}') into v_blocked from social.my_blocked_ids() b;

  if v_cell >= 1.0 and profiles.aggregates_fresh() then
    -- Continente / mundo: re-agrupar la rejilla precalculada (miles de filas, no todos los socios).
    with g as (
      select * from profiles.map_grid mg
       where (p_fases is null or mg.fase = any (p_fases))
         and (mg.cell_x + 0.5) * 0.25 between v_w and v_e
         and (mg.cell_y + 0.5) * 0.25 between v_s and v_n),
    cells as (
      select sum(n)::int as n, sum(sum_lat) / sum(n) as lat, sum(sum_lng) / sum(n) as lng,
             any_value(any_user) as uno
        from g group by floor((cell_x + 0.5) * 0.25 / v_cell), floor((cell_y + 0.5) * 0.25 / v_cell)),
    shown as (
      select c.*, case when c.n = 1 then (
               -- Celda de un solo socio: comprobación en vivo antes de enseñar su ficha.
               select jsonb_build_object('user_id', p.user_id, 'slug', p.slug, 'nombre', p.nombre, 'fase', p.fase,
                        'promocion', p.promocion, 'foto_path', p.foto_path, 'ciudad', p.ciudad, 'pais', p.pais)
                 from profiles.profiles p
                 join identity.members m on m.user_id = p.user_id and m.status = 'active'
                where p.user_id = c.uno and p.ubicacion is not null
                  and coalesce(p.visibilidad ->> 'ubicacion', 'socios') = 'socios'
                  and p.user_id <> all (v_blocked)) end as alumni
        from cells c)
    select coalesce(jsonb_agg(jsonb_build_object(
             'lat', round(s.lat::numeric, 4), 'lng', round(s.lng::numeric, 4), 'count', s.n,
             'alumni', s.alumni) order by s.n desc), '[]'::jsonb)
      into v_clusters
      from shown s
     where s.n > 1 or s.alumni is not null;
  else
    -- Ciudad / región (o caché no disponible): en vivo, con el índice espacial.
    with pts as (
      select p.user_id, p.ubicacion::extensions.geometry as g
        from profiles.profiles p
        join identity.members m on m.user_id = p.user_id and m.status = 'active'
       where p.ubicacion is not null
         and extensions.st_intersects(p.ubicacion::extensions.geometry, v_env)
         and (p.user_id = v_uid or coalesce(p.visibilidad ->> 'ubicacion', 'socios') = 'socios')
         and (p_fases is null or p.fase = any (p_fases))
         and p.user_id <> all (v_blocked)),
    cells as (
      select count(*) as n, avg(extensions.st_y(g)) as lat, avg(extensions.st_x(g)) as lng,
             any_value(user_id) as uno
        from pts group by extensions.st_snaptogrid(g, v_cell))
    select coalesce(jsonb_agg(jsonb_build_object(
             'lat', round(c.lat::numeric, 4), 'lng', round(c.lng::numeric, 4), 'count', c.n,
             'alumni', case when c.n = 1 then (
                select jsonb_build_object('user_id', p.user_id, 'slug', p.slug, 'nombre', p.nombre, 'fase', p.fase,
                         'promocion', p.promocion, 'foto_path', p.foto_path, 'ciudad', p.ciudad, 'pais', p.pais)
                  from profiles.profiles p where p.user_id = c.uno) end) order by c.n desc), '[]'::jsonb)
      into v_clusters from cells c;
  end if;

  if p_include_clubs then
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', c.id, 'nombre', c.nombre, 'ciudad', c.ciudad, 'pais', c.pais,
             'lat', extensions.st_y(c.ubicacion::extensions.geometry),
             'lng', extensions.st_x(c.ubicacion::extensions.geometry),
             'miembros_count', c.miembros_count)), '[]'::jsonb)
      into v_clubs
      from clubs.clubs c
     where extensions.st_intersects(c.ubicacion::extensions.geometry, v_env);
  end if;

  return jsonb_build_object('zoom', v_zoom, 'cell_deg', v_cell,
    'total', (select coalesce(sum((c ->> 'count')::int), 0) from jsonb_array_elements(v_clusters) c),
    'clusters', v_clusters, 'clubs', v_clubs);
end;
$$;

-- ---------------------------------------------------------------- suggestions ---
-- Antes: puntuaba a TODOS los perfiles. Ahora solo a candidatos sacados por índice: los 500
-- amigos de amigos más conectados y, de cada grupo (promoción, ciudad, empresa, sector), los
-- 300 con más seguidores. Es una heurística: en comunidades enormes alguien con varias
-- coincidencias pero pocos seguidores puede quedar fuera; a cambio el coste es constante.
create index if not exists profiles_sug_promo_idx on profiles.profiles (promocion, seguidores_count desc, user_id)
  where acepta_sugerencias;
create index if not exists profiles_sug_ciudad_idx on profiles.profiles (ciudad, seguidores_count desc, user_id)
  where acepta_sugerencias;
create index if not exists profiles_sug_empresa_idx on profiles.profiles (empresa, seguidores_count desc, user_id)
  where acepta_sugerencias;
create index if not exists profiles_sug_sector_idx on profiles.profiles (sector, seguidores_count desc, user_id)
  where acepta_sugerencias;

create or replace function api.suggestions(p_limit int default 5)
returns jsonb language sql stable security invoker set search_path = ''
as $$
  with me as (select p.* from profiles.profiles p where p.user_id = identity.require_member()),
  excluded as (
    select (select user_id from me) as id
    union select social.my_followed_ids()
    union select social.my_blocked_ids()),
  fof as (
    select f2.seguido_id as id, count(*) as n
      from social.follows f1 join social.follows f2 on f2.seguidor_id = f1.seguido_id
     where f1.seguidor_id = (select user_id from me)
     group by f2.seguido_id),
  candidates as (
    (select id from fof order by n desc, id limit 500)
    union (select p.user_id from profiles.profiles p, me where p.acepta_sugerencias and p.promocion = me.promocion
            order by p.seguidores_count desc, p.user_id limit 300)
    union (select p.user_id from profiles.profiles p, me where p.acepta_sugerencias and p.ciudad = me.ciudad
            order by p.seguidores_count desc, p.user_id limit 300)
    union (select p.user_id from profiles.profiles p, me where p.acepta_sugerencias and p.empresa = me.empresa
            order by p.seguidores_count desc, p.user_id limit 300)
    union (select p.user_id from profiles.profiles p, me where p.acepta_sugerencias and p.sector = me.sector
            order by p.seguidores_count desc, p.user_id limit 300)),
  scored as (
    select p.user_id, p.seguidores_count,
           coalesce(fof.n, 0) * 3
           + case when p.promocion = me.promocion then 4 else 0 end
           + case when p.ciudad is not null and p.ciudad = me.ciudad then 3 else 0 end
           + case when p.empresa is not null and p.empresa = me.empresa then 3 else 0 end
           + case when p.sector is not null and p.sector = me.sector then 1 else 0 end as score
      from candidates c
      join profiles.profiles p on p.user_id = c.id
      cross join me
      left join fof on fof.id = p.user_id
     where p.acepta_sugerencias
       and p.user_id not in (select id from excluded where id is not null)),
  top as (
    select s.user_id, s.score from scored s
     where s.score > 0
     order by s.score desc, s.seguidores_count desc, s.user_id
     limit least(greatest(p_limit, 1), 20))
  select coalesce(jsonb_agg(profiles.card(p, (select user_id from me), false)
           || jsonb_build_object('is_following', false, 'score', t.score)
           order by t.score desc, p.seguidores_count desc, p.user_id), '[]'::jsonb)
    from top t join profiles.profiles p on p.user_id = t.user_id;
$$;
