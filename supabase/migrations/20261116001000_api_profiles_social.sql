-- =============================================================================
-- ICEX Atlas · 1000 · API: sesión, perfiles, directorio, social
-- Convenciones:
--   * security invoker por defecto (RLS aplica); definer solo si se documenta.
--   * Todas exigen socio activo (identity.require_member) → un no socio no obtiene nada.
--   * Listas paginadas por cursor keyset; devuelven {items, next_cursor}.
-- =============================================================================

-- --------------------------------------------------------------- sesión -------
create or replace function api.me()
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_role text;
  v_profile jsonb;
begin
  select m.role::text into v_role from identity.members m where m.user_id = v_uid;
  select profiles.card(p, v_uid, false) || jsonb_build_object(
           'bio', p.bio, 'pais_code', p.pais_code, 'visibilidad', p.visibilidad,
           'acepta_sugerencias', p.acepta_sugerencias, 'posts_count', p.posts_count,
           'lat', extensions.st_y(p.ubicacion::extensions.geometry), 'lng', extensions.st_x(p.ubicacion::extensions.geometry))
    into v_profile
    from profiles.profiles p where p.user_id = v_uid;
  return jsonb_build_object('user_id', v_uid, 'role', v_role, 'profile', v_profile);
end;
$$;

-- Heartbeat (D-008/push): la app lo llama cada 60 s en primer plano.
-- definer: actualiza una columna de identity.members que el socio no puede tocar.
create or replace function api.heartbeat()
returns void language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  update identity.members set last_seen_at = now() where user_id = v_uid;
end;
$$;

-- ------------------------------------------------------------- perfiles -------
create or replace function api.get_profile(p_slug text default null, p_user uuid default null)
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  p profiles.profiles;
  v_follows boolean;
  v_is_owner boolean;
  v_exps jsonb;
begin
  select * into p from profiles.profiles pr
   where (p_user is not null and pr.user_id = p_user) or (p_slug is not null and pr.slug = p_slug)
   limit 1;
  if p.user_id is null then
    raise exception 'Perfil no encontrado' using errcode = 'P0002';
  end if;
  if social.is_blocked_between(v_uid, p.user_id) and p.user_id <> v_uid then
    raise exception 'Perfil no disponible' using errcode = 'P0002';
  end if;

  v_is_owner := p.user_id = v_uid;
  v_follows := social.follows_user(v_uid, p.user_id);

  if profiles.can_see(p.visibilidad, 'trayectoria', v_is_owner, v_follows) then
    select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'empresa', e.empresa, 'cargo', e.cargo,
             'desde', e.desde, 'hasta', e.hasta) order by e.desde desc), '[]'::jsonb)
      into v_exps from profiles.experiences e where e.user_id = p.user_id;
  else
    v_exps := '[]'::jsonb;
  end if;

  return profiles.card(p, v_uid, v_follows) || jsonb_build_object(
    'bio', case when profiles.can_see(p.visibilidad, 'bio', v_is_owner, v_follows) then p.bio end,
    'posts_count', p.posts_count,
    'experiences', v_exps,
    'is_self', v_is_owner,
    'is_following', v_follows,
    'follows_me', social.follows_user(p.user_id, v_uid),
    'visibilidad', case when v_is_owner then p.visibilidad end,
    'acepta_sugerencias', case when v_is_owner then p.acepta_sugerencias end);
end;
$$;

create or replace function api.update_my_profile(
  p_nombre text default null, p_cargo text default null, p_empresa text default null,
  p_fase profiles.fase default null, p_pais text default null, p_pais_code text default null,
  p_ciudad text default null, p_sector text default null, p_bio text default null,
  p_lat double precision default null, p_lng double precision default null, p_foto_path text default null)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  if p_foto_path is not null and p_foto_path not like v_uid::text || '/%' then
    raise exception 'Ruta de foto no válida' using errcode = '22023';
  end if;
  if (p_lat is null) <> (p_lng is null) or (p_lat is not null and (abs(p_lat) > 90 or abs(p_lng) > 180)) then
    raise exception 'Coordenadas no válidas' using errcode = '22023';
  end if;
  update profiles.profiles set
    nombre    = coalesce(nullif(trim(p_nombre), ''), nombre),
    cargo     = case when p_cargo is null then cargo else nullif(trim(p_cargo), '') end,
    empresa   = case when p_empresa is null then empresa else nullif(trim(p_empresa), '') end,
    fase      = coalesce(p_fase, fase),
    pais      = case when p_pais is null then pais else nullif(trim(p_pais), '') end,
    pais_code = case when p_pais_code is null then pais_code else upper(nullif(trim(p_pais_code), '')) end,
    ciudad    = case when p_ciudad is null then ciudad else nullif(trim(p_ciudad), '') end,
    sector    = case when p_sector is null then sector else nullif(trim(p_sector), '') end,
    bio       = case when p_bio is null then bio else nullif(trim(p_bio), '') end,
    -- precisión de ciudad: 2 decimales (~1 km) por privacidad
    ubicacion = case when p_lat is null then ubicacion
                else extensions.st_setsrid(extensions.st_makepoint(round(p_lng::numeric, 2)::float8,
                       round(p_lat::numeric, 2)::float8), 4326)::extensions.geography end,
    foto_path = coalesce(p_foto_path, foto_path)
  where user_id = v_uid;
  return api.get_profile(p_user => v_uid);
end;
$$;

create or replace function api.set_privacy(p_visibilidad jsonb default null, p_acepta_sugerencias boolean default null)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  k text;
begin
  if p_visibilidad is not null then
    for k in select jsonb_object_keys(p_visibilidad) loop
      if k not in ('cargo', 'empresa', 'ciudad', 'ubicacion', 'bio', 'trayectoria')
         or p_visibilidad ->> k not in ('socios', 'seguidores', 'solo_yo') then
        raise exception 'Valor de privacidad no válido: %', k using errcode = '22023';
      end if;
    end loop;
  end if;
  update profiles.profiles
     set visibilidad = case when p_visibilidad is null then visibilidad else visibilidad || p_visibilidad end,
         acepta_sugerencias = coalesce(p_acepta_sugerencias, acepta_sugerencias)
   where user_id = v_uid;
  return api.get_profile(p_user => v_uid);
end;
$$;

create or replace function api.upsert_experience(
  p_id uuid, p_empresa text, p_cargo text, p_desde date, p_hasta date default null)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  insert into profiles.experiences (id, user_id, empresa, cargo, desde, hasta)
  values (p_id, v_uid, trim(p_empresa), trim(p_cargo), p_desde, p_hasta)
  on conflict (id) do update
    set empresa = excluded.empresa, cargo = excluded.cargo, desde = excluded.desde, hasta = excluded.hasta
    where profiles.experiences.user_id = v_uid;
  return api.get_profile(p_user => v_uid);
end;
$$;

create or replace function api.delete_experience(p_id uuid)
returns void language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  delete from profiles.experiences where id = p_id and user_id = v_uid;
end;
$$;

-- ------------------------------------------------------------ directorio ------
-- Búsqueda con pg_trgm (índice GIN sobre profiles.busqueda) + filtros + keyset (nombre, user_id).
-- p_tab: 'todos' | 'mi_promocion' | 'exterior' | 'activo'
create or replace function api.search_directory(
  p_query text default null, p_promocion int default null, p_fase profiles.fase default null,
  p_tab text default 'todos', p_cursor text default null, p_limit int default 24)
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_my_promo int;
  v_tokens text[];
  v_limit int := least(greatest(coalesce(p_limit, 24), 1), 50);
  v_c_nombre text := nullif(split_part(coalesce(p_cursor, ''), chr(31), 1), '');
  v_c_id uuid := nullif(split_part(coalesce(p_cursor, ''), chr(31), 2), '')::uuid;
  v_items jsonb;
  v_total int;
  v_page_n int;
begin
  if p_tab = 'mi_promocion' then
    select promocion into v_my_promo from profiles.profiles where user_id = v_uid;
  end if;
  v_tokens := array_remove(regexp_split_to_array(util.normalize(trim(coalesce(p_query, ''))), '\s+'), '');

  with hits as (
    select p.user_id, p.nombre
      from profiles.profiles p
     where (cardinality(v_tokens) = 0 or not exists (
              select 1 from unnest(v_tokens) t where p.busqueda not like '%' || t || '%'))
       and (p_promocion is null or p.promocion = p_promocion)
       and (p_fase is null or p.fase = p_fase)
       and (coalesce(p_tab, 'todos') <> 'mi_promocion' or p.promocion = v_my_promo)
       and (coalesce(p_tab, 'todos') <> 'exterior' or p.en_el_exterior)
       and (coalesce(p_tab, 'todos') <> 'activo' or p.fase = 'activo')
       and p.user_id not in (select social.my_blocked_ids())),
  page as (
    select h.user_id, h.nombre from hits h
     where v_c_nombre is null or (h.nombre, h.user_id) > (v_c_nombre, v_c_id)
     order by h.nombre, h.user_id
     limit v_limit + 1)
  select (select count(*) from hits),
         (select count(*) from page),
         (select coalesce(jsonb_agg(
                   profiles.card(p, v_uid, f.f) || jsonb_build_object('is_following', f.f)
                   order by p.nombre, p.user_id), '[]'::jsonb)
            from (select * from page order by nombre, user_id limit v_limit) pg
            join profiles.profiles p on p.user_id = pg.user_id
            cross join lateral (select social.follows_user(v_uid, p.user_id) as f) f)
    into v_total, v_page_n, v_items;

  return jsonb_build_object(
    'items', v_items,
    'total', v_total,
    'next_cursor', case when v_page_n > v_limit
                     then (v_items -> (v_limit - 1) ->> 'nombre') || chr(31) || (v_items -> (v_limit - 1) ->> 'user_id') end);
end;
$$;

-- "Personas que quizá conozcas": misma promoción, ciudad, empresa o seguidos por mis seguidos.
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
  scored as (
    select p.user_id,
           coalesce(fof.n, 0) * 3
           + case when p.promocion = me.promocion then 4 else 0 end
           + case when p.ciudad is not null and p.ciudad = me.ciudad then 3 else 0 end
           + case when p.empresa is not null and p.empresa = me.empresa then 3 else 0 end
           + case when p.sector is not null and p.sector = me.sector then 1 else 0 end as score
      from profiles.profiles p
      cross join me
      left join fof on fof.id = p.user_id
     where p.acepta_sugerencias
       and p.user_id not in (select id from excluded where id is not null)),
  top as (
    select s.user_id, s.score from scored s
      join profiles.profiles p on p.user_id = s.user_id
     where s.score > 0
     order by s.score desc, p.seguidores_count desc, s.user_id
     limit least(greatest(p_limit, 1), 20))
  select coalesce(jsonb_agg(profiles.card(p, (select user_id from me), false)
           || jsonb_build_object('is_following', false, 'score', t.score)
           order by t.score desc, p.seguidores_count desc, p.user_id), '[]'::jsonb)
    from top t join profiles.profiles p on p.user_id = t.user_id;
$$;

-- ---------------------------------------------------------------- social ------
create or replace function api.follow(p_user uuid)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  if p_user = v_uid then raise exception 'No puedes seguirte a ti mismo' using errcode = '22023'; end if;
  insert into social.follows (seguidor_id, seguido_id) values (v_uid, p_user)
  on conflict do nothing;
  return jsonb_build_object('is_following', true,
    'seguidores_count', (select seguidores_count from profiles.profiles where user_id = p_user));
end;
$$;

create or replace function api.unfollow(p_user uuid)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  delete from social.follows where seguidor_id = v_uid and seguido_id = p_user;
  return jsonb_build_object('is_following', false,
    'seguidores_count', (select seguidores_count from profiles.profiles where user_id = p_user));
end;
$$;

create or replace function api.block(p_user uuid)
returns void language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  insert into social.blocks (bloqueador_id, bloqueado_id) values (v_uid, p_user) on conflict do nothing;
end;
$$;

create or replace function api.unblock(p_user uuid)
returns void language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  delete from social.blocks where bloqueador_id = v_uid and bloqueado_id = p_user;
end;
$$;

create or replace function api.list_blocked()
returns jsonb language sql stable security invoker set search_path = ''
as $$
  select coalesce(jsonb_agg(profiles.card(p, identity.require_member(), false) order by p.nombre), '[]'::jsonb)
    from social.blocks b join profiles.profiles p on p.user_id = b.bloqueado_id
   where b.bloqueador_id = (select auth.uid());
$$;

-- p_direction: 'seguidores' | 'siguiendo'. Keyset por (created_at desc, user_id).
create or replace function api.list_follows(p_user uuid, p_direction text default 'seguidores',
  p_cursor text default null, p_limit int default 30)
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_limit int := least(greatest(coalesce(p_limit, 30), 1), 100);
  v_items jsonb;
begin
  with rows as (
    select case when p_direction = 'siguiendo' then f.seguido_id else f.seguidor_id end as uid, f.created_at
      from social.follows f
     where (p_direction = 'siguiendo' and f.seguidor_id = p_user)
        or (p_direction <> 'siguiendo' and f.seguido_id = p_user)),
  page as (
    select r.* from rows r
     where (p_cursor is null or (r.created_at, r.uid) < (util.cursor_ts(p_cursor), util.cursor_id(p_cursor)))
       and r.uid not in (select social.my_blocked_ids())
     order by r.created_at desc, r.uid desc limit v_limit)
  select coalesce(jsonb_agg(profiles.card(p, v_uid, social.follows_user(v_uid, p.user_id))
           || jsonb_build_object('is_following', social.follows_user(v_uid, p.user_id),
                                 '_cursor', util.encode_cursor(pg.created_at, pg.uid))
           order by pg.created_at desc, pg.uid desc), '[]'::jsonb)
    into v_items
    from page pg join profiles.profiles p on p.user_id = pg.uid;
  return jsonb_build_object('items', v_items,
    'next_cursor', case when jsonb_array_length(v_items) = v_limit then v_items -> (v_limit - 1) ->> '_cursor' end);
end;
$$;

-- "La comunidad en cifras". Si la asociación fija cifras oficiales (config), se usan esas.
create or replace function api.community_stats()
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_override jsonb;
  v_uid uuid := identity.require_member();
begin
  v_override := config.get('community.stats_override');
  if v_override is not null and v_override <> 'null'::jsonb then
    return v_override;
  end if;
  return (select jsonb_build_object(
    'alumni', count(*),
    'activos', count(*) filter (where p.fase = 'activo'),
    'paises', count(distinct p.pais_code),
    'promociones', count(distinct p.promocion))
    from profiles.profiles p);
end;
$$;

create or replace function api.app_config()
returns jsonb language sql stable security invoker set search_path = ''
as $$
  select case when identity.require_member() is null then null else
    coalesce(jsonb_object_agg(c.key, c.value), '{}'::jsonb) end
    from config.app_config c;
$$;
