-- =============================================================================
-- ICEX Atlas · 20261124-0200 · Rendimiento a escala
-- Hallazgos de supabase/stress/scale.py con 30.000 socios, 1,2 M seguimientos, 180.000 posts,
-- 930.000 mensajes (p95 en serie, antes → después, en el portátil de pruebas):
--  · get_feed: 16 s → <100 ms. El bloque de «novedades oficiales» recorría el índice de TODOS
--    los posts buscando las pocas novedades (y evaluando RLS en cada uno). Índice parcial propio.
--  · RLS de posts: feed.can_view(posts) se ejecutaba por fila (≈0,2 ms cada una, sin poder
--    «inlinear»). Ahora la política es una expresión con subconsultas iniciales (una vez por
--    consulta): misma semántica, una fracción del coste.
--  · map_clusters (mundo): construía un JSON por cada socio para quedarse con uno por celda.
--  · alumni_near / map_clusters: con RLS activo, Postgres NO puede usar el índice GiST (los
--    operadores de PostGIS no son «leakproof») → recorrido completo de perfiles. Pasan a
--    SECURITY DEFINER: exigen socio (require_member) y aplican ellas mismas los mismos filtros
--    que la RLS (socio activo, visibilidad de la ubicación, bloqueos). KNN sobre el índice.
-- =============================================================================

-- ------------------------------------------------------------------- feed -----
create index if not exists posts_novedades_feed_idx on feed.posts (created_at desc, id desc)
  where tipo = 'novedad_oficial' and not oculto and not fijado;

-- Misma regla que feed.can_view(p), escrita para que Postgres la evalúe barata:
-- lo que depende solo del usuario (socio, moderador, bloqueados) se calcula una vez.
drop policy if exists posts_select on feed.posts;
create policy posts_select on feed.posts for select to authenticated using (
  (select identity.is_member())
  and (not oculto or autor_id = (select auth.uid()) or (select identity.is_moderator()))
  and autor_id <> all (array(select b from social.my_blocked_ids() b))
  and (visibilidad = 'socios' or autor_id = (select auth.uid()) or social.follows_user((select auth.uid()), autor_id))
);

-- -------------------------------------------------------------------- mapa ----
-- El mapa filtra por rectángulo en coordenadas planas (geometry): índice sobre esa expresión.
create index if not exists profiles_ubicacion_geom_gix on profiles.profiles
  using gist ((ubicacion::extensions.geometry)) where ubicacion is not null;
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
  v_env extensions.geometry;
  v_blocked uuid[];
  v_clusters jsonb;
  v_clubs jsonb := '[]'::jsonb;
begin
  -- Envolvente (sin cruzar el antimeridiano; el cliente parte la vista si hace falta).
  v_env := extensions.st_makeenvelope(greatest(p_west, -180), greatest(p_south, -85),
                                      least(p_east, 180), least(p_north, 85), 4326);
  select coalesce(array_agg(b), '{}') into v_blocked from social.my_blocked_ids() b;

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
    -- Solo agregados: el detalle de un socio se busca después, y solo en celdas de uno.
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

create or replace function api.alumni_near(p_lat double precision, p_lng double precision,
  p_radius_km double precision default 25, p_limit int default 30)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_pt extensions.geography := extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography;
  v_blocked uuid[];
begin
  select coalesce(array_agg(b), '{}') into v_blocked from social.my_blocked_ids() b;
  return (
    with near as (
      -- KNN (<->) sobre el índice GiST: lee los más cercanos primero y para al llegar al límite.
      select p.user_id, extensions.st_distance(p.ubicacion, v_pt) as d
        from profiles.profiles p
        join identity.members m on m.user_id = p.user_id and m.status = 'active'
       where p.ubicacion is not null
         and coalesce(p.visibilidad ->> 'ubicacion', 'socios') = 'socios'
         and extensions.st_dwithin(p.ubicacion, v_pt, least(p_radius_km, 500) * 1000)
         and p.user_id <> all (v_blocked)
       order by p.ubicacion operator(extensions.<->) v_pt
       limit least(greatest(p_limit, 1), 100))
    select coalesce(jsonb_agg(profiles.card(p, v_uid, false) order by n.d), '[]'::jsonb)
      from near n join profiles.profiles p on p.user_id = n.user_id);
end;
$$;
