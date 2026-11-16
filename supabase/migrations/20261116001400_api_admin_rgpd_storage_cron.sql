-- =============================================================================
-- ICEX Atlas · 1400 · API admin/moderación, RGPD, Storage, Cron y permisos finales
-- =============================================================================

-- ------------------------------------------------------------ denuncias -------
create or replace function api.report(p_target_tipo moderation.target_tipo, p_target_id uuid,
  p_motivo moderation.motivo, p_detalle text default null)
returns uuid language plpgsql security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_owner uuid;
  v_id uuid;
begin
  -- Solo se puede denunciar lo que uno puede ver (RLS en cada módulo).
  v_owner := case p_target_tipo
    when 'post' then (select autor_id from feed.posts where id = p_target_id)
    when 'comentario' then (select autor_id from feed.comments where id = p_target_id)
    when 'perfil' then (select user_id from profiles.profiles where user_id = p_target_id)
    when 'mensaje' then (select remitente_id from messaging.messages where id = p_target_id) end;
  if v_owner is null then raise exception 'Contenido no encontrado' using errcode = 'P0002'; end if;
  if v_owner = v_uid then raise exception 'No puedes denunciar tu propio contenido' using errcode = '22023'; end if;
  insert into moderation.reports (reporter_id, target_tipo, target_id, target_owner, motivo, detalle)
  values (v_uid, p_target_tipo, p_target_id, v_owner, p_motivo, left(p_detalle, 1000))
  on conflict do nothing
  returning id into v_id;
  return v_id;
end;
$$;

-- ------------------------------------------------------------- admin ----------
create or replace function api.admin_dashboard()
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
begin
  if not identity.is_moderator() then raise exception 'Solo moderación/administración' using errcode = '42501'; end if;
  return jsonb_build_object(
    'socios_activos', (select count(*) from identity.members where status = 'active'),
    'denuncias_pendientes', (select count(*) from moderation.reports where estado in ('pendiente', 'en_revision')),
    'novedades', (select count(*) from feed.posts where tipo = 'novedad_oficial'),
    'clubs', (select count(*) from clubs.clubs),
    'posts_7d', (select count(*) from feed.posts where created_at > now() - interval '7 days'));
end;
$$;

create or replace function api.admin_publish_news(p_id uuid, p_titulo text, p_texto text,
  p_etiqueta text default null, p_fijado boolean default false, p_media text[] default '{}')
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  if not identity.is_admin() then raise exception 'Solo administración' using errcode = '42501'; end if;
  insert into feed.posts (id, autor_id, tipo, titulo, etiqueta, texto, fijado, media)
  values (p_id, v_uid, 'novedad_oficial', trim(p_titulo), nullif(trim(p_etiqueta), ''), trim(p_texto),
          coalesce(p_fijado, false), coalesce(p_media, '{}'))
  on conflict (id) do update set titulo = excluded.titulo, texto = excluded.texto,
    etiqueta = excluded.etiqueta, fijado = excluded.fijado, media = excluded.media
  where feed.posts.tipo = 'novedad_oficial';
  return api.get_post(p_id);
end;
$$;

create or replace function api.admin_set_pinned(p_post uuid, p_fijado boolean)
returns void language plpgsql security invoker set search_path = ''
as $$
begin
  if not identity.is_admin() then raise exception 'Solo administración' using errcode = '42501'; end if;
  update feed.posts set fijado = p_fijado where id = p_post;
end;
$$;

create or replace function api.admin_list_reports(p_estado moderation.estado default null, p_limit int default 50)
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
begin
  if not identity.is_moderator() then raise exception 'Solo moderación' using errcode = '42501'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object(
      'id', r.id, 'target_tipo', r.target_tipo, 'target_id', r.target_id, 'motivo', r.motivo,
      'detalle', r.detalle, 'estado', r.estado, 'resolucion', r.resolucion, 'created_at', r.created_at,
      'denunciante', (select jsonb_build_object('user_id', p.user_id, 'nombre', p.nombre) from profiles.profiles p where p.user_id = r.reporter_id),
      'autor', (select jsonb_build_object('user_id', p.user_id, 'nombre', p.nombre, 'slug', p.slug) from profiles.profiles p where p.user_id = r.target_owner),
      'contenido', case r.target_tipo
         when 'post' then (select left(texto, 500) from feed.posts where id = r.target_id)
         when 'comentario' then (select left(texto, 500) from feed.comments where id = r.target_id)
         when 'perfil' then (select coalesce(bio, nombre) from profiles.profiles where user_id = r.target_id)
         else '(mensaje privado: revisar con el denunciante)' end)
      order by r.created_at), '[]'::jsonb)
    from (select * from moderation.reports r
           where (p_estado is null and r.estado in ('pendiente', 'en_revision')) or r.estado = p_estado
           order by r.created_at limit least(greatest(p_limit, 1), 200)) r);
end;
$$;

-- p_accion: 'descartar' | 'ocultar_contenido' | 'suspender_socio' (este último solo admin)
create or replace function api.admin_resolve_report(p_report uuid, p_accion text, p_resolucion text default null)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  r moderation.reports;
begin
  if not identity.is_moderator() then raise exception 'Solo moderación' using errcode = '42501'; end if;
  select * into r from moderation.reports where id = p_report for update;
  if r.id is null then raise exception 'Denuncia no encontrada' using errcode = 'P0002'; end if;

  if p_accion = 'ocultar_contenido' then
    if r.target_tipo = 'post' then update feed.posts set oculto = true where id = r.target_id;
    elsif r.target_tipo = 'comentario' then update feed.comments set oculto = true where id = r.target_id;
    elsif r.target_tipo = 'mensaje' then delete from messaging.messages where id = r.target_id;
    end if;
  elsif p_accion = 'suspender_socio' then
    if not identity.is_admin() then raise exception 'Solo administración puede suspender' using errcode = '42501'; end if;
    update identity.members set status = 'suspended' where user_id = r.target_owner;
    delete from auth.sessions where user_id = r.target_owner;
  elsif p_accion <> 'descartar' then
    raise exception 'Acción no válida' using errcode = '22023';
  end if;

  update moderation.reports
     set estado = case when p_accion = 'descartar' then 'descartada'::moderation.estado else 'accion_tomada' end,
         resolucion = coalesce(p_resolucion, p_accion), resuelto_por = v_uid, resuelto_en = now()
   where target_tipo = r.target_tipo and target_id = r.target_id and estado in ('pendiente', 'en_revision');
end;
$$;

create or replace function api.admin_upsert_club(p_id uuid, p_nombre text, p_ciudad text, p_pais text,
  p_lat double precision, p_lng double precision, p_pais_code text default null, p_descripcion text default null)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  if not identity.is_admin() then raise exception 'Solo administración' using errcode = '42501'; end if;
  insert into clubs.clubs (id, nombre, ciudad, pais, pais_code, ubicacion, descripcion)
  values (p_id, p_nombre, p_ciudad, p_pais, upper(p_pais_code),
          extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography, p_descripcion)
  on conflict (id) do update set nombre = excluded.nombre, ciudad = excluded.ciudad, pais = excluded.pais,
    pais_code = excluded.pais_code, ubicacion = excluded.ubicacion, descripcion = excluded.descripcion;
  return api.get_club(p_id);
end;
$$;

create or replace function api.admin_delete_club(p_id uuid)
returns void language plpgsql security invoker set search_path = ''
as $$
begin
  if not identity.is_admin() then raise exception 'Solo administración' using errcode = '42501'; end if;
  delete from clubs.clubs where id = p_id;
end;
$$;

create or replace function api.admin_set_club_role(p_club uuid, p_user uuid, p_rol clubs.club_rol)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if not identity.is_admin() then raise exception 'Solo administración' using errcode = '42501'; end if;
  insert into clubs.club_members (club_id, user_id, rol) values (p_club, p_user, p_rol)
  on conflict (club_id, user_id) do update set rol = excluded.rol;
end;
$$;

create or replace function api.admin_search_members(p_query text default null, p_limit int default 50)
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
begin
  if not identity.is_admin() then raise exception 'Solo administración' using errcode = '42501'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('user_id', m.user_id, 'nombre', p.nombre, 'slug', p.slug,
            'role', m.role, 'status', m.status, 'promocion', p.promocion) order by p.nombre), '[]'::jsonb)
    from (select * from profiles.profiles p
           where p_query is null or p.busqueda like '%' || util.normalize(p_query) || '%'
           order by p.nombre limit least(greatest(p_limit, 1), 200)) p
    join identity.members m on m.user_id = p.user_id);
end;
$$;

create or replace function api.admin_set_member_role(p_user uuid, p_role identity.member_role)
returns void language plpgsql security invoker set search_path = ''
as $$
begin
  if not identity.is_admin() then raise exception 'Solo administración' using errcode = '42501'; end if;
  if p_user = auth.uid() and p_role <> 'admin' then
    raise exception 'No puedes quitarte el rol de administración' using errcode = '22023';
  end if;
  update identity.members set role = p_role where user_id = p_user;   -- RLS: members_admin_update
end;
$$;

create or replace function api.admin_set_config(p_key text, p_value jsonb)
returns void language plpgsql security invoker set search_path = ''
as $$
begin
  if not identity.is_admin() then raise exception 'Solo administración' using errcode = '42501'; end if;
  insert into config.app_config (key, value) values (p_key, p_value)
  on conflict (key) do update set value = excluded.value;
end;
$$;

-- ---------------------------------------------------------------- RGPD --------
-- Exportación completa (art. 15 y 20 RGPD) en JSON. security invoker: RLS garantiza
-- que solo salen datos accesibles al titular.
create or replace function api.export_my_data()
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  return jsonb_build_object(
    'generado_en', now(),
    'cuenta', (select jsonb_build_object('user_id', m.user_id, 'rol', m.role, 'estado', m.status,
                 'verificado_en', m.verified_at, 'alta', m.created_at) from identity.members m where m.user_id = v_uid),
    'perfil', (select to_jsonb(p) - 'busqueda' from profiles.profiles p where p.user_id = v_uid),
    'trayectoria', (select coalesce(jsonb_agg(to_jsonb(e)), '[]') from profiles.experiences e where e.user_id = v_uid),
    'siguiendo', (select coalesce(jsonb_agg(jsonb_build_object('user_id', f.seguido_id, 'desde', f.created_at)), '[]')
                    from social.follows f where f.seguidor_id = v_uid),
    'seguidores', (select coalesce(jsonb_agg(jsonb_build_object('user_id', f.seguidor_id, 'desde', f.created_at)), '[]')
                     from social.follows f where f.seguido_id = v_uid),
    'bloqueos', (select coalesce(jsonb_agg(jsonb_build_object('user_id', b.bloqueado_id, 'desde', b.created_at)), '[]')
                   from social.blocks b where b.bloqueador_id = v_uid),
    'publicaciones', (select coalesce(jsonb_agg(to_jsonb(p)), '[]') from feed.posts p where p.autor_id = v_uid),
    'comentarios', (select coalesce(jsonb_agg(to_jsonb(c)), '[]') from feed.comments c where c.autor_id = v_uid),
    'recomendaciones', (select coalesce(jsonb_agg(to_jsonb(r)), '[]') from feed.recommendations r where r.user_id = v_uid),
    'mensajes_enviados', (select coalesce(jsonb_agg(messaging.message_json(m) order by m.id), '[]')
                            from messaging.messages m where m.remitente_id = v_uid),
    'conversaciones', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'categoria', c.categoria, 'creada', c.created_at)), '[]')
                         from messaging.conversations c where messaging.is_participant(c.id, v_uid)),
    'clubs', (select coalesce(jsonb_agg(to_jsonb(cm)), '[]') from clubs.club_members cm where cm.user_id = v_uid),
    'inscripciones', (select coalesce(jsonb_agg(to_jsonb(a)), '[]') from clubs.event_attendees a where a.user_id = v_uid),
    'notificaciones', (select coalesce(jsonb_agg(to_jsonb(n)), '[]') from notifications.notifications n where n.user_id = v_uid),
    'preferencias', (select to_jsonb(p) from notifications.preferences p where p.user_id = v_uid),
    'dispositivos_push', (select coalesce(jsonb_agg(jsonb_build_object('plataforma', t.plataforma, 'actualizado', t.updated_at)), '[]')
                            from notifications.push_tokens t where t.user_id = v_uid),
    'orientador_consultas', (select coalesce(jsonb_agg(to_jsonb(q)), '[]') from orientador.queries q where q.user_id = v_uid),
    'denuncias_presentadas', (select coalesce(jsonb_agg(jsonb_build_object('tipo', r.target_tipo, 'motivo', r.motivo,
                                'estado', r.estado, 'fecha', r.created_at)), '[]')
                                from moderation.reports r where r.reporter_id = v_uid));
end;
$$;

-- Borrado completo (art. 17 RGPD). Antes, la Edge Function `account-delete` borra
-- los ficheros del socio en Storage. Aquí: mensajes enviados + usuario de Auth
-- (en cascada: members → perfil, posts, comentarios, seguidores, notificaciones…).
create or replace function api.delete_my_account(p_confirmacion text)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  if p_confirmacion is distinct from 'BORRAR MI CUENTA' then
    raise exception 'Confirmación incorrecta' using errcode = '22023';
  end if;
  delete from messaging.messages where remitente_id = v_uid;
  delete from moderation.reports where reporter_id = v_uid;
  delete from orientador.documents where user_id = v_uid;
  delete from auth.users where id = v_uid;
end;
$$;

-- -------------------------------------------------------------- Storage -------
-- Buckets privados (la app es privada). Las subidas pasan por la Edge Function
-- `media-upload` (valida tipo real por magic bytes, tamaño y elimina EXIF).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
       ('post-media', 'post-media', false, 8388608, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "socios leen imagenes" on storage.objects for select to authenticated
  using (bucket_id in ('avatars', 'post-media') and (select identity.is_member()));
create policy "socios borran sus imagenes" on storage.objects for delete to authenticated
  using (bucket_id in ('avatars', 'post-media') and (select identity.is_member())
         and (storage.foldername(name))[1] = (select auth.uid())::text);
-- Sin política de INSERT/UPDATE para clientes: solo service_role (Edge Function) sube.

-- ----------------------------------------------------------------- Cron -------
-- Las tareas HTTP leen la URL del proyecto y la clave de servicio de Vault
-- (secretos `project_url` y `service_role_key`, ver docs/runbook.md).
create or replace function util.invoke_edge_function(p_name text, p_body jsonb default '{}'::jsonb)
returns bigint language plpgsql security definer set search_path = ''
as $$
declare
  v_url text := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url');
  v_key text := (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key');
begin
  if v_url is null or v_key is null then
    raise log 'invoke_edge_function: faltan secretos de Vault (project_url/service_role_key)';
    return null;
  end if;
  return net.http_post(
    url := v_url || '/functions/v1/' || p_name,
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_key),
    body := p_body,
    timeout_milliseconds := 55000);
end;
$$;
revoke execute on function util.invoke_edge_function(text, jsonb) from public, authenticated, anon;

create or replace function orientador.purge_old_queries()
returns int language plpgsql security definer set search_path = ''
as $$
declare v int;
begin
  delete from orientador.queries where created_at < now() - interval '30 days';
  get diagnostics v = row_count;
  return v;
end;
$$;

select cron.schedule('messaging-partitions', '0 3 1 * *',
  $$select messaging.ensure_partitions(current_date, 4)$$);
select cron.schedule('orientador-purge', '30 3 * * *',
  $$select orientador.purge_old_queries()$$);
select cron.schedule('notifications-purge', '45 3 * * 0',
  $$delete from notifications.notifications where leido and updated_at < now() - interval '180 days'$$);
select cron.schedule('push-dispatch', '* * * * *',
  $$select util.invoke_edge_function('push-dispatcher')$$);
select cron.schedule('orientador-index', '* * * * *',
  $$select util.invoke_edge_function('orientador-indexer')$$);
-- 02:15 UTC ≈ 03:15 en Madrid (horario de invierno)
select cron.schedule('membership-sync', '15 2 * * *',
  $$select util.invoke_edge_function('membership-sync')$$);

-- ------------------------------------------------------- permisos finales -----
revoke execute on all functions in schema api from public, anon;
grant execute on all functions in schema api to authenticated, service_role;
