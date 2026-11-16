-- =============================================================================
-- ICEX Atlas · 1100 · API: feed, novedades, comentarios, recomendaciones
-- =============================================================================

-- Representación JSON de un post para el usuario actual (autor con privacidad aplicada).
create or replace function feed.post_json(p feed.posts, p_viewer uuid)
returns jsonb language sql stable set search_path = ''
as $$
  select jsonb_build_object(
    'id', p.id,
    'tipo', p.tipo,
    'titulo', p.titulo,
    'etiqueta', p.etiqueta,
    'texto', p.texto,
    'media', to_jsonb(p.media),
    'visibilidad', p.visibilidad,
    'club_id', p.club_id,
    'fijado', p.fijado,
    'recomendaciones_count', p.recomendaciones_count,
    'comentarios_count', p.comentarios_count,
    'compartidos_count', p.compartidos_count,
    'created_at', p.created_at,
    'recomendado', exists (select 1 from feed.recommendations r where r.post_id = p.id and r.user_id = p_viewer),
    'autor', (select profiles.card(pr, p_viewer, social.follows_user(p_viewer, pr.user_id))
                from profiles.profiles pr where pr.user_id = p.autor_id),
    'compartido', case when p.compartido_de is null then null else (
       select jsonb_build_object('id', o.id, 'tipo', o.tipo, 'texto', o.texto, 'created_at', o.created_at,
                'autor', (select profiles.card(pr, p_viewer, false) from profiles.profiles pr where pr.user_id = o.autor_id))
         from feed.posts o where o.id = p.compartido_de and feed.can_view(o)) end,
    '_cursor', util.encode_cursor(p.created_at, p.id));
$$;
grant execute on function feed.post_json(feed.posts, uuid) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- Timeline fase 1 (fan-out on read):
--   publicaciones de quienes sigo + mías + de mis clubs + novedades oficiales,
--   orden cronológico, keyset (created_at, id). En la primera página, las novedades
--   fijadas se devuelven aparte en `destacadas` para pintarlas arriba.
-- -----------------------------------------------------------------------------
create or replace function api.get_feed(p_cursor text default null, p_limit int default 20)
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_limit int := least(greatest(coalesce(p_limit, (config.get('feed.page_size', '20'))::int), 1), 50);
  v_ts timestamptz := coalesce(util.cursor_ts(p_cursor), 'infinity'::timestamptz);
  v_id uuid := coalesce(util.cursor_id(p_cursor), 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid);
  v_items jsonb;
  v_pinned jsonb := '[]'::jsonb;
begin
  with authors as (
         select v_uid as id
         union select social.my_followed_ids()),
       candidates as (
         -- Index scan por autor (posts_autor_created_idx): como mucho v_limit por autor.
         (select p.* from authors a
            cross join lateral (
              select * from feed.posts p
               where p.autor_id = a.id and not p.oculto
                 and (p.created_at, p.id) < (v_ts, v_id)
                 and p.tipo <> 'novedad_oficial'
               order by p.created_at desc, p.id desc
               limit v_limit) p)
         union
         (select p.* from (select clubs.my_club_ids() as cid) c
            cross join lateral (
              select * from feed.posts p
               where p.club_id = c.cid and not p.oculto
                 and (p.created_at, p.id) < (v_ts, v_id)
               order by p.created_at desc, p.id desc
               limit v_limit) p)
         union
         (select p.* from feed.posts p
           where p.tipo = 'novedad_oficial' and not p.oculto and not p.fijado
             and (p.created_at, p.id) < (v_ts, v_id)
           order by p.created_at desc, p.id desc
           limit v_limit)),
       page as (
         select c.* from candidates c
          where not social.is_blocked_between(v_uid, c.autor_id)
          order by c.created_at desc, c.id desc
          limit v_limit)
  select coalesce(jsonb_agg(feed.post_json(pg::feed.posts, v_uid) order by pg.created_at desc, pg.id desc), '[]'::jsonb)
    into v_items
    from page pg;

  if p_cursor is null then
    select coalesce(jsonb_agg(feed.post_json(p, v_uid) order by p.created_at desc), '[]'::jsonb)
      into v_pinned
      from (select * from feed.posts p
             where p.tipo = 'novedad_oficial' and p.fijado and not p.oculto
             order by p.created_at desc limit 3) p;
  end if;

  return jsonb_build_object(
    'items', v_items,
    'destacadas', v_pinned,
    'next_cursor', case when jsonb_array_length(v_items) = v_limit then v_items -> (v_limit - 1) ->> '_cursor' end);
end;
$$;

-- Novedades oficiales de la asociación (fijadas primero en la primera página).
create or replace function api.get_news(p_cursor text default null, p_limit int default 20)
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_limit int := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_items jsonb;
  v_pinned jsonb := '[]'::jsonb;
begin
  -- Las fijadas solo en la primera página y fuera del keyset.
  if p_cursor is null then
    select coalesce(jsonb_agg(feed.post_json(p, v_uid) order by p.created_at desc, p.id desc), '[]'::jsonb)
      into v_pinned
      from feed.posts p where p.tipo = 'novedad_oficial' and p.fijado and not p.oculto;
  end if;
  select coalesce(jsonb_agg(feed.post_json(p, v_uid) order by p.created_at desc, p.id desc), '[]'::jsonb)
    into v_items
    from (select * from feed.posts p
           where p.tipo = 'novedad_oficial' and not p.oculto and not p.fijado
             and (p.created_at, p.id) < (coalesce(util.cursor_ts(p_cursor), 'infinity'),
                                         coalesce(util.cursor_id(p_cursor), 'ffffffff-ffff-ffff-ffff-ffffffffffff'))
           order by p.created_at desc, p.id desc
           limit v_limit) p;
  return jsonb_build_object('items', v_items, 'destacadas', v_pinned,
    'total', (select count(*) from feed.posts p where p.tipo = 'novedad_oficial' and not p.oculto),
    'next_cursor', case when jsonb_array_length(v_items) = v_limit then v_items -> (v_limit - 1) ->> '_cursor' end);
end;
$$;

create or replace function api.get_user_posts(p_user uuid, p_cursor text default null, p_limit int default 20)
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_limit int := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_items jsonb;
begin
  select coalesce(jsonb_agg(feed.post_json(p, v_uid) order by p.created_at desc, p.id desc), '[]'::jsonb)
    into v_items
    from (select * from feed.posts p
           where p.autor_id = p_user and not p.oculto
             and (p.created_at, p.id) < (coalesce(util.cursor_ts(p_cursor), 'infinity'),
                                         coalesce(util.cursor_id(p_cursor), 'ffffffff-ffff-ffff-ffff-ffffffffffff'))
           order by p.created_at desc, p.id desc limit v_limit) p;
  return jsonb_build_object('items', v_items,
    'next_cursor', case when jsonb_array_length(v_items) = v_limit then v_items -> (v_limit - 1) ->> '_cursor' end);
end;
$$;

create or replace function api.get_post(p_id uuid)
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v jsonb;
begin
  select feed.post_json(p, v_uid) into v from feed.posts p where p.id = p_id;
  if v is null then raise exception 'Publicación no disponible' using errcode = 'P0002'; end if;
  return v;
end;
$$;

-- Publicar (idempotente por id UUIDv7 generado en la app).
create or replace function api.create_post(
  p_id uuid, p_texto text, p_tipo feed.post_tipo default 'general', p_media text[] default '{}',
  p_visibilidad feed.post_visibilidad default 'socios', p_club_id uuid default null,
  p_compartido_de uuid default null)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_existing feed.posts;
  m text;
begin
  if p_tipo = 'novedad_oficial' then
    raise exception 'Las novedades oficiales se publican desde el panel de administración' using errcode = '42501';
  end if;
  foreach m in array coalesce(p_media, '{}') loop
    if m not like v_uid::text || '/%' then
      raise exception 'Ruta de imagen no válida' using errcode = '22023';
    end if;
  end loop;
  if p_club_id is not null and not exists (select 1 from clubs.my_club_ids() c where c = p_club_id) then
    raise exception 'Solo puedes publicar en clubs de los que eres miembro' using errcode = '42501';
  end if;
  if p_compartido_de is not null and not feed.can_view_post(p_compartido_de) then
    raise exception 'Publicación original no disponible' using errcode = 'P0002';
  end if;

  select * into v_existing from feed.posts where id = p_id;
  if v_existing.id is not null then
    if v_existing.autor_id <> v_uid then raise exception 'Id en uso' using errcode = '23505'; end if;
    return feed.post_json(v_existing, v_uid);   -- reintento: misma respuesta
  end if;

  insert into feed.posts (id, autor_id, tipo, texto, media, visibilidad, club_id, compartido_de)
  values (p_id, v_uid, p_tipo, trim(p_texto), coalesce(p_media, '{}'), p_visibilidad, p_club_id, p_compartido_de);
  return api.get_post(p_id);
end;
$$;

create or replace function api.delete_post(p_id uuid)
returns void language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  delete from feed.posts where id = p_id;   -- RLS: autor o moderador
  if not found then raise exception 'No se puede borrar' using errcode = '42501'; end if;
end;
$$;

create or replace function api.recommend(p_post uuid)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  insert into feed.recommendations (post_id, user_id) values (p_post, v_uid) on conflict do nothing;
  return jsonb_build_object('recomendado', true,
    'recomendaciones_count', (select recomendaciones_count from feed.posts where id = p_post));
end;
$$;

create or replace function api.unrecommend(p_post uuid)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  delete from feed.recommendations where post_id = p_post and user_id = v_uid;
  return jsonb_build_object('recomendado', false,
    'recomendaciones_count', (select recomendaciones_count from feed.posts where id = p_post));
end;
$$;

create or replace function api.get_comments(p_post uuid, p_cursor text default null, p_limit int default 30)
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_limit int := least(greatest(coalesce(p_limit, 30), 1), 100);
  v_items jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id, 'post_id', c.post_id, 'texto', c.texto, 'created_at', c.created_at,
           'autor', (select profiles.card(pr, v_uid, false) from profiles.profiles pr where pr.user_id = c.autor_id),
           '_cursor', util.encode_cursor(c.created_at, c.id))
         order by c.created_at, c.id), '[]'::jsonb)
    into v_items
    from (select * from feed.comments c
           where c.post_id = p_post
             and (p_cursor is null or (c.created_at, c.id) > (util.cursor_ts(p_cursor), util.cursor_id(p_cursor)))
           order by c.created_at, c.id limit v_limit) c;
  return jsonb_build_object('items', v_items,
    'next_cursor', case when jsonb_array_length(v_items) = v_limit then v_items -> (v_limit - 1) ->> '_cursor' end);
end;
$$;

create or replace function api.add_comment(p_id uuid, p_post uuid, p_texto text)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  insert into feed.comments (id, post_id, autor_id, texto)
  values (p_id, p_post, v_uid, trim(p_texto))
  on conflict (id) do nothing;
  return (select jsonb_build_object('id', c.id, 'post_id', c.post_id, 'texto', c.texto, 'created_at', c.created_at,
            'autor', (select profiles.card(pr, v_uid, false) from profiles.profiles pr where pr.user_id = c.autor_id))
            from feed.comments c where c.id = p_id);
end;
$$;

create or replace function api.delete_comment(p_id uuid)
returns void language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  delete from feed.comments where id = p_id;
end;
$$;
