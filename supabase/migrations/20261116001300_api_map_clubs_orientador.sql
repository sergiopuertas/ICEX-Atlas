-- =============================================================================
-- ICEX Atlas · 1300 · API: mapa (PostGIS), clubs y eventos, orientador (pgvector)
-- =============================================================================

-- ------------------------------------------------------------------ mapa ------
-- Clusters por zoom calculados en SQL: rejilla en grados = 360 / 2^zoom / 3
-- (≈ 85 px por celda con teselas de 256 px). Solo socios que muestran su ubicación
-- a todos los socios (o uno mismo). Ubicación a nivel de ciudad (ver profiles).
create or replace function api.map_clusters(
  p_zoom int, p_west double precision, p_south double precision,
  p_east double precision, p_north double precision,
  p_fases profiles.fase[] default null, p_include_clubs boolean default true)
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_zoom int := least(greatest(coalesce(p_zoom, 2), 0), 18);
  v_cell double precision := 360.0 / power(2, v_zoom) / 3.0;
  v_env extensions.geometry;
  v_clusters jsonb;
  v_clubs jsonb := '[]'::jsonb;
begin
  -- Envolvente (sin cruzar el antimeridiano; el cliente parte la vista si hace falta).
  v_env := extensions.st_makeenvelope(greatest(p_west, -180), greatest(p_south, -85),
                                      least(p_east, 180), least(p_north, 85), 4326);

  with pts as (
    select p.user_id, p.slug, p.nombre, p.fase, p.promocion, p.foto_path, p.ciudad, p.pais,
           p.ubicacion::extensions.geometry as g
      from profiles.profiles p
     where p.ubicacion is not null
       and extensions.st_intersects(p.ubicacion::extensions.geometry, v_env)
       and (p.user_id = v_uid or coalesce(p.visibilidad ->> 'ubicacion', 'socios') = 'socios')
       and (p_fases is null or p.fase = any (p_fases))
       and p.user_id not in (select social.my_blocked_ids())),
  cells as (
    select extensions.st_snaptogrid(g, v_cell) as cell,
           count(*) as n,
           avg(extensions.st_y(g)) as lat,
           avg(extensions.st_x(g)) as lng,
           (array_agg(jsonb_build_object('user_id', user_id, 'slug', slug, 'nombre', nombre, 'fase', fase,
                       'promocion', promocion, 'foto_path', foto_path, 'ciudad', ciudad, 'pais', pais)))[1] as uno
      from pts group by 1)
  select coalesce(jsonb_agg(jsonb_build_object(
           'lat', round(lat::numeric, 4), 'lng', round(lng::numeric, 4), 'count', n,
           'alumni', case when n = 1 then uno end) order by n desc), '[]'::jsonb)
    into v_clusters from cells;

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

-- Alumni cercanos a un punto (radio en km), para la ficha de cluster.
create or replace function api.alumni_near(p_lat double precision, p_lng double precision,
  p_radius_km double precision default 25, p_limit int default 30)
returns jsonb language sql stable security invoker set search_path = ''
as $$
  with pt as (select extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography as g),
  near as (
    select p.user_id, extensions.st_distance(p.ubicacion, pt.g) as d
      from profiles.profiles p, pt
     where p.ubicacion is not null
       and coalesce(p.visibilidad ->> 'ubicacion', 'socios') = 'socios'
       and extensions.st_dwithin(p.ubicacion, pt.g, least(p_radius_km, 500) * 1000)
       and p.user_id not in (select social.my_blocked_ids())
     order by d limit least(greatest(p_limit, 1), 100))
  select coalesce(jsonb_agg(profiles.card(p, identity.require_member(), false) order by n.d), '[]'::jsonb)
    from near n join profiles.profiles p on p.user_id = n.user_id;
$$;

-- ----------------------------------------------------------------- clubs ------
create or replace function clubs.club_json(c clubs.clubs, p_viewer uuid)
returns jsonb language sql stable set search_path = ''
as $$
  select jsonb_build_object('id', c.id, 'nombre', c.nombre, 'ciudad', c.ciudad, 'pais', c.pais,
    'descripcion', c.descripcion, 'miembros_count', c.miembros_count,
    'lat', extensions.st_y(c.ubicacion::extensions.geometry), 'lng', extensions.st_x(c.ubicacion::extensions.geometry),
    'mi_rol', (select cm.rol from clubs.club_members cm where cm.club_id = c.id and cm.user_id = p_viewer));
$$;
grant execute on function clubs.club_json(clubs.clubs, uuid) to authenticated, service_role;

create or replace function clubs.event_json(e clubs.events, p_viewer uuid)
returns jsonb language sql stable set search_path = ''
as $$
  select jsonb_build_object('id', e.id, 'club_id', e.club_id, 'titulo', e.titulo, 'descripcion', e.descripcion,
    'inicio', e.inicio, 'fin', e.fin, 'lugar', e.lugar, 'online_url', e.online_url, 'aforo', e.aforo,
    'inscritos_count', e.inscritos_count,
    'club_nombre', (select c.nombre from clubs.clubs c where c.id = e.club_id),
    'mi_inscripcion', (select a.estado from clubs.event_attendees a where a.event_id = e.id and a.user_id = p_viewer));
$$;
grant execute on function clubs.event_json(clubs.events, uuid) to authenticated, service_role;

create or replace function api.list_clubs(p_query text default null)
returns jsonb language sql stable security invoker set search_path = ''
as $$
  select coalesce(jsonb_agg(clubs.club_json(c, identity.require_member()) order by c.pais, c.ciudad), '[]'::jsonb)
    from clubs.clubs c
   where p_query is null or util.normalize(c.nombre || ' ' || c.ciudad || ' ' || c.pais) like '%' || util.normalize(p_query) || '%';
$$;

create or replace function api.get_club(p_club uuid)
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member(); v jsonb;
begin
  select clubs.club_json(c, v_uid) || jsonb_build_object(
           'proximos_eventos', (select coalesce(jsonb_agg(clubs.event_json(e, v_uid) order by e.inicio), '[]'::jsonb)
                                  from clubs.events e where e.club_id = c.id and e.inicio >= now() - interval '1 day'),
           'organizadores', (select coalesce(jsonb_agg(profiles.card(p, v_uid, false)), '[]'::jsonb)
                               from clubs.club_members cm join profiles.profiles p on p.user_id = cm.user_id
                              where cm.club_id = c.id and cm.rol = 'organizador'))
    into v from clubs.clubs c where c.id = p_club;
  if v is null then raise exception 'Club no encontrado' using errcode = 'P0002'; end if;
  return v;
end;
$$;

create or replace function api.join_club(p_club uuid)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  insert into clubs.club_members (club_id, user_id) values (p_club, v_uid) on conflict do nothing;
  return api.get_club(p_club);
end;
$$;

create or replace function api.leave_club(p_club uuid)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  delete from clubs.club_members where club_id = p_club and user_id = v_uid;
  return api.get_club(p_club);
end;
$$;

create or replace function api.list_events(p_club uuid default null, p_from timestamptz default null, p_limit int default 30)
returns jsonb language sql stable security invoker set search_path = ''
as $$
  select coalesce(jsonb_agg(clubs.event_json(e, identity.require_member()) order by e.inicio, e.id), '[]'::jsonb)
    from (select * from clubs.events e
           where (p_club is null or e.club_id = p_club)
             and e.inicio >= coalesce(p_from, now() - interval '1 day')
           order by e.inicio, e.id limit least(greatest(p_limit, 1), 100)) e;
$$;

create or replace function api.create_event(p_id uuid, p_club uuid, p_titulo text, p_inicio timestamptz,
  p_descripcion text default null, p_fin timestamptz default null, p_lugar text default null,
  p_online_url text default null, p_aforo int default null)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  insert into clubs.events (id, club_id, titulo, descripcion, inicio, fin, lugar, online_url, aforo, created_by)
  values (p_id, p_club, p_titulo, p_descripcion, p_inicio, p_fin, p_lugar, p_online_url, p_aforo, v_uid)
  on conflict (id) do nothing;
  return (select clubs.event_json(e, v_uid) from clubs.events e where e.id = p_id);
end;
$$;

-- Inscripción con control de aforo (bloqueo de la fila del evento → sin sobreventa).
-- definer: event_attendees no admite INSERT directo de clientes.
create or replace function api.register_event(p_event uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_ev clubs.events;
  v_estado clubs.inscripcion_estado;
begin
  select * into v_ev from clubs.events where id = p_event for update;
  if v_ev.id is null then raise exception 'Evento no encontrado' using errcode = 'P0002'; end if;
  if v_ev.inicio < now() then raise exception 'El evento ya ha comenzado' using errcode = '22023'; end if;
  v_estado := case when v_ev.aforo is not null and v_ev.inscritos_count >= v_ev.aforo
                   then 'lista_espera' else 'inscrito' end;
  insert into clubs.event_attendees (event_id, user_id, estado) values (p_event, v_uid, v_estado)
  on conflict do nothing;
  return (select clubs.event_json(e, v_uid) from clubs.events e where e.id = p_event);
end;
$$;

create or replace function api.cancel_event_registration(p_event uuid)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  delete from clubs.event_attendees where event_id = p_event and user_id = v_uid;
  return (select clubs.event_json(e, v_uid) from clubs.events e where e.id = p_event);
end;
$$;

-- ------------------------------------------------------------- orientador -----
-- Las llama la Edge Function `orientador` con el JWT del socio.

-- Reserva una consulta respetando el límite diario (bloqueo asesor por socio).
create or replace function api.orientador_reserve(p_id uuid, p_fase text, p_pais text, p_sector text, p_consulta text)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_limit int := coalesce((config.get('orientador.daily_limit', '10'))::int, 10);
  v_used int;
begin
  if not coalesce((config.get('orientador.enabled', 'true'))::boolean, true) then
    raise exception 'El Orientador está desactivado temporalmente' using errcode = 'P0001';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('orientador:' || v_uid::text, 0));
  select count(*) into v_used from orientador.queries
   where user_id = v_uid and created_at >= date_trunc('day', now() at time zone 'Europe/Madrid') at time zone 'Europe/Madrid';
  if v_used >= v_limit then
    raise exception 'Has alcanzado el límite de % consultas diarias' , v_limit using errcode = 'P0001', hint = 'rate_limited';
  end if;
  insert into orientador.queries (id, user_id, fase, pais, sector, consulta)
  values (p_id, v_uid, p_fase, p_pais, p_sector, left(coalesce(p_consulta, ''), 2000))
  on conflict (id) do nothing;
  return jsonb_build_object('id', p_id, 'restantes', v_limit - v_used - 1, 'limite', v_limit);
end;
$$;

-- Contexto por similitud (pgvector, coseno) con prioridad a país/sector. Solo socios
-- que aceptan ser sugeridos (documents solo contiene esos), excluyendo bloqueos y a uno mismo.
create or replace function api.orientador_context(p_embedding text, p_pais text default null,
  p_sector text default null, p_limit int default 8)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_q extensions.vector(384) := p_embedding::extensions.vector(384);
begin
  return (
    with ranked as (
      select d.*, (d.embedding operator(extensions.<=>) v_q)
                  - case when p_pais is not null and d.pais = p_pais then 0.08 else 0 end
                  - case when p_sector is not null and d.sector = p_sector then 0.05 else 0 end as score
        from orientador.documents d
       where d.embedding is not null
         and d.user_id is distinct from v_uid
         and (d.user_id is null or not social.is_blocked_between(v_uid, d.user_id))
       order by d.embedding operator(extensions.<=>) v_q
       limit 60)
    select jsonb_build_object(
      'perfiles', coalesce((select jsonb_agg(x.j) from (
          select profiles.card(p, v_uid, false) || jsonb_build_object('score', round(r.score::numeric, 4)) j
            from ranked r join profiles.profiles p on p.user_id = r.source_id
           where r.source_tipo = 'perfil' and p.acepta_sugerencias
           order by r.score limit least(p_limit, 10)) x), '[]'::jsonb),
      'publicaciones', coalesce((select jsonb_agg(x.j) from (
          select jsonb_build_object('post_id', r.source_id, 'extracto', left(r.contenido, 280),
                   'score', round(r.score::numeric, 4)) j
            from ranked r where r.source_tipo in ('post', 'guia')
           order by r.score limit least(p_limit, 10)) x), '[]'::jsonb)));
end;
$$;

create or replace function api.orientador_complete(p_id uuid, p_respuesta jsonb, p_proveedor text)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  update orientador.queries set respuesta = p_respuesta, proveedor = p_proveedor
   where id = p_id and user_id = v_uid;
end;
$$;

create or replace function api.orientador_history(p_limit int default 20)
returns jsonb language sql stable security invoker set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', q.id, 'fase', q.fase, 'pais', q.pais, 'sector', q.sector,
           'consulta', q.consulta, 'respuesta', q.respuesta, 'created_at', q.created_at) order by q.created_at desc), '[]'::jsonb)
    from (select * from orientador.queries q where q.user_id = identity.require_member()
           order by q.created_at desc limit least(greatest(p_limit, 1), 50)) q;
$$;
