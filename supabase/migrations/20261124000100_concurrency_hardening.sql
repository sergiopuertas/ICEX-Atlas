-- =============================================================================
-- ICEX Atlas · 20261124-0100 · Endurecimiento frente a concurrencia
-- Hallazgos de supabase/stress/concurrency.py (pruebas con decenas de conexiones reales):
--  1. Un mensaje enviado con retraso (escrito sin cobertura) hacía RETROCEDER el «último
--     mensaje» de la conversación y el puntero de leído del remitente → contadores de no
--     leídos incoherentes.
--  2. El id del mensaje lo pone el cliente (UUID v7, ordena la conversación). Un id aleatorio
--     (v4) o con fecha futura quedaba «siempre el último» y rompía no_leidos y la paginación.
--  3. Seguir / escribir a un socio que borra su cuenta en ese instante devolvía la violación
--     de clave ajena en crudo (23503 → error desconocido en la app). Ahora: P0002 controlado.
--  4. La agrupación de notificaciones dependía de un bloqueo indirecto (el contador del post)
--     para no chocar con el índice único; ahora es atómica (INSERT … ON CONFLICT).
-- =============================================================================

-- ---------------------------------------------------------------- utilidades --

-- Bloquea (FOR KEY SHARE) la fila del socio activo: un borrado concurrente espera a que
-- terminemos en vez de hacer fallar nuestras claves ajenas a mitad de transacción.
create or replace function identity.lock_active_member(p_user uuid)
returns boolean language sql volatile security definer set search_path = ''
as $$
  select exists (select 1 from identity.members m
                  where m.user_id = p_user and m.status = 'active'
                  for key share);
$$;
revoke execute on function identity.lock_active_member(uuid) from public, anon;
grant execute on function identity.lock_active_member(uuid) to authenticated, service_role;

-- Valida el id de un mensaje: UUID v7 con una marca de tiempo no futura (tolerancia de
-- reloj de 5 min). Se aceptan ids antiguos: reintentos de mensajes escritos sin conexión.
create or replace function messaging.assert_message_id(p_id uuid)
returns void language plpgsql immutable set search_path = ''
as $$
begin
  if p_id is null or substr(p_id::text, 15, 1) <> '7' or substr(p_id::text, 20, 1) not in ('8', '9', 'a', 'b') then
    raise exception 'Id de mensaje no válido (se espera UUID v7)' using errcode = '22023';
  end if;
end;
$$;

-- ------------------------------------------------------------- send_message --
create or replace function api.send_message(
  p_id uuid,
  p_cuerpo text,
  p_conversation_id uuid default null,
  p_to uuid default null,
  p_categoria messaging.categoria default null)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_conv uuid := p_conversation_id;
  v_msg messaging.messages;
  v_cuerpo text := trim(coalesce(p_cuerpo, ''));
begin
  if v_cuerpo = '' then
    raise exception 'Mensaje vacío' using errcode = '22023';
  end if;
  perform messaging.assert_message_id(p_id);
  if util.uuid_v7_time(p_id) > now() + interval '5 minutes' then
    raise exception 'Id de mensaje con fecha futura (revisa la hora del dispositivo)' using errcode = '22023';
  end if;
  if char_length(v_cuerpo) > 4000 then
    raise exception 'Mensaje demasiado largo' using errcode = '22001';
  end if;

  -- Idempotencia: si el id ya existe, devolverlo (reintento tras corte de red).
  select * into v_msg from messaging.messages where id = p_id;
  if v_msg.id is not null then
    if v_msg.remitente_id is distinct from v_uid then
      raise exception 'Id de mensaje en uso' using errcode = '23505';
    end if;
    return messaging.message_json(v_msg) || jsonb_build_object('duplicado', true);
  end if;

  if v_conv is null then
    if p_to is null or p_to = v_uid then
      raise exception 'Destinatario no válido' using errcode = '22023';
    end if;
    -- Bloquea al destinatario: si borra su cuenta ahora, espera a que terminemos.
    if not identity.lock_active_member(p_to) then
      raise exception 'El destinatario no es socio activo' using errcode = '42501';
    end if;
    insert into messaging.conversations (tipo, categoria, direct_key, creado_por)
    values ('directa', coalesce(p_categoria, 'networking'), messaging.direct_key(v_uid, p_to), v_uid)
    on conflict (direct_key) do nothing
    returning id into v_conv;
    if v_conv is null then
      select id into v_conv from messaging.conversations where direct_key = messaging.direct_key(v_uid, p_to);
    else
      insert into messaging.conversation_members (conversation_id, user_id) values (v_conv, v_uid), (v_conv, p_to)
      on conflict do nothing;
    end if;
  end if;

  if not messaging.is_participant(v_conv, v_uid) then
    raise exception 'No participas en esta conversación' using errcode = '42501';
  end if;
  if exists (select 1 from messaging.conversation_members cm
              where cm.conversation_id = v_conv and cm.user_id <> v_uid
                and (social.is_blocked_between(v_uid, cm.user_id) or not identity.is_member_id(cm.user_id))) then
    raise exception 'No es posible enviar mensajes a este socio' using errcode = '42501';
  end if;

  insert into messaging.messages (id, conversation_id, remitente_id, cuerpo)
  values (p_id, v_conv, v_uid, v_cuerpo)
  on conflict (id) do nothing
  returning * into v_msg;
  if v_msg.id is null then
    select * into v_msg from messaging.messages where id = p_id;
    return messaging.message_json(v_msg) || jsonb_build_object('duplicado', true);
  end if;

  -- El «último mensaje» solo avanza (un envío retrasado con id antiguo no lo pisa).
  update messaging.conversations c
     set ultimo_mensaje_en = case when c.ultimo_mensaje_id is null or v_msg.id > c.ultimo_mensaje_id
                                  then v_msg.created_at else c.ultimo_mensaje_en end,
         ultimo_mensaje_preview = case when c.ultimo_mensaje_id is null or v_msg.id > c.ultimo_mensaje_id
                                       then left(v_cuerpo, 140) else c.ultimo_mensaje_preview end,
         ultimo_mensaje_id = case when c.ultimo_mensaje_id is null or v_msg.id > c.ultimo_mensaje_id
                                  then v_msg.id else c.ultimo_mensaje_id end,
         categoria = coalesce(p_categoria, c.categoria)
   where c.id = v_conv;

  -- Remitente: escribir implica haber leído hasta aquí; el puntero nunca retrocede y los no
  -- leídos se recalculan (lo recibido después de su propio mensaje sigue contando).
  -- Destinatarios: +1 siempre, también si llega tarde con un id antiguo: para ellos es nuevo.
  -- (api.mark_read recalcula el número exacto al abrir la conversación.)
  update messaging.conversation_members cm
     set ultimo_leido_id = case when cm.user_id = v_uid
                                then greatest(coalesce(cm.ultimo_leido_id, v_msg.id), v_msg.id)
                                else cm.ultimo_leido_id end,
         no_leidos = case
           when cm.user_id = v_uid then
             (select count(*) from messaging.messages m
               where m.conversation_id = v_conv and m.remitente_id <> v_uid
                 and m.id > greatest(coalesce(cm.ultimo_leido_id, v_msg.id), v_msg.id))
           else cm.no_leidos + 1 end,
         archivado = false
   where cm.conversation_id = v_conv;

  perform pgmq.send('message_events', jsonb_build_object(
    'message_id', v_msg.id, 'conversation_id', v_conv, 'remitente_id', v_uid,
    'destinatarios', (select coalesce(jsonb_agg(cm.user_id), '[]'::jsonb) from messaging.conversation_members cm
                       where cm.conversation_id = v_conv and cm.user_id <> v_uid and not cm.silenciado)));

  perform realtime.send(jsonb_build_object('conversation_id', v_conv, 'message_id', v_msg.id),
            'conversation.updated', 'user:' || cm.user_id::text, true)
     from messaging.conversation_members cm where cm.conversation_id = v_conv;

  return messaging.message_json(v_msg) || jsonb_build_object('duplicado', false);
end;
$$;

-- ------------------------------------------------------------------- follow --
create or replace function api.follow(p_user uuid)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  if p_user = v_uid then raise exception 'No puedes seguirte a ti mismo' using errcode = '22023'; end if;
  if not identity.lock_active_member(p_user) then
    raise exception 'Socio no encontrado' using errcode = 'P0002';
  end if;
  insert into social.follows (seguidor_id, seguido_id) values (v_uid, p_user)
  on conflict do nothing;
  return jsonb_build_object('is_following', true,
    'seguidores_count', (select seguidores_count from profiles.profiles where user_id = p_user));
end;
$$;

-- ----------------------------------------------------------- notifications --
-- Agrupación atómica: una sola notificación sin leer por (usuario, group_key), sin carreras.
create or replace function notifications.notify(
  p_user uuid, p_tipo notifications.tipo, p_actor uuid, p_payload jsonb, p_group_key text default null)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare v_id uuid;
begin
  if p_user is null or p_user = p_actor then return null; end if;
  if not identity.is_member_id(p_user) then return null; end if;
  if p_actor is not null and social.is_blocked_between(p_user, p_actor) then return null; end if;

  if p_group_key is null then
    insert into notifications.notifications (user_id, tipo, group_key, actor_ids, payload)
    values (p_user, p_tipo, null, case when p_actor is null then '{}' else array[p_actor] end, p_payload)
    returning id into v_id;
  else
    insert into notifications.notifications as n (user_id, tipo, group_key, actor_ids, payload)
    values (p_user, p_tipo, p_group_key, case when p_actor is null then '{}' else array[p_actor] end, p_payload)
    on conflict (user_id, group_key) where not leido and group_key is not null
    do update set total = n.total + 1,
                  actor_ids = (array_prepend(p_actor, array_remove(n.actor_ids, p_actor)))[1:5],
                  payload = n.payload || excluded.payload,
                  updated_at = now()
       where p_actor is null or not (p_actor = any (n.actor_ids))
    returning n.id into v_id;
    if v_id is null then
      return null; -- mismo actor repitiendo la acción: no duplicar ni volver a avisar
    end if;
  end if;

  if notifications.wants_push(p_user, p_tipo) then
    perform pgmq.send('push', jsonb_build_object(
      'notification_id', v_id, 'user_id', p_user, 'tipo', p_tipo, 'actor_id', p_actor, 'payload', p_payload));
  end if;

  perform realtime.send(jsonb_build_object('notification_id', v_id, 'tipo', p_tipo),
    'notification.created', 'user:' || p_user::text, true);
  return v_id;
end;
$$;

-- ------------------------------------------- objetos borrados a la vez -------
-- Recomendar / comentar / compartir un post o unirse a un club que otro borra en ese mismo
-- instante: bloqueo FOR KEY SHARE previo → el borrado espera, o devolvemos P0002 limpio.
create or replace function feed.lock_post(p_post uuid)
returns boolean language sql volatile security definer set search_path = ''
as $$ select exists (select 1 from feed.posts p where p.id = p_post for key share); $$;
create or replace function clubs.lock_club(p_club uuid)
returns boolean language sql volatile security definer set search_path = ''
as $$ select exists (select 1 from clubs.clubs c where c.id = p_club for key share); $$;
revoke execute on function feed.lock_post(uuid), clubs.lock_club(uuid) from public, anon;
grant execute on function feed.lock_post(uuid), clubs.lock_club(uuid) to authenticated, service_role;

create or replace function api.recommend(p_post uuid)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  if not feed.lock_post(p_post) then
    raise exception 'Publicación no encontrada' using errcode = 'P0002';
  end if;
  insert into feed.recommendations (post_id, user_id) values (p_post, v_uid) on conflict do nothing;
  return jsonb_build_object('recomendado', true,
    'recomendaciones_count', (select recomendaciones_count from feed.posts where id = p_post));
end;
$$;

create or replace function api.add_comment(p_id uuid, p_post uuid, p_texto text)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  if not feed.lock_post(p_post) then
    raise exception 'Publicación no encontrada' using errcode = 'P0002';
  end if;
  insert into feed.comments (id, post_id, autor_id, texto)
  values (p_id, p_post, v_uid, trim(p_texto))
  on conflict (id) do nothing;
  return (select jsonb_build_object('id', c.id, 'post_id', c.post_id, 'texto', c.texto, 'created_at', c.created_at,
            'autor', (select profiles.card(pr, v_uid, false) from profiles.profiles pr where pr.user_id = c.autor_id))
            from feed.comments c where c.id = p_id and c.autor_id = v_uid);
end;
$$;

create or replace function api.join_club(p_club uuid)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  if not clubs.lock_club(p_club) then
    raise exception 'Club no encontrado' using errcode = 'P0002';
  end if;
  insert into clubs.club_members (club_id, user_id) values (p_club, v_uid) on conflict do nothing;
  return api.get_club(p_club);
end;
$$;

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
  if p_club_id is not null and (not clubs.lock_club(p_club_id)
                                or not exists (select 1 from clubs.my_club_ids() c where c = p_club_id)) then
    raise exception 'Solo puedes publicar en clubs de los que eres miembro' using errcode = '42501';
  end if;
  if p_compartido_de is not null and (not feed.lock_post(p_compartido_de) or not feed.can_view_post(p_compartido_de)) then
    raise exception 'Publicación original no disponible' using errcode = 'P0002';
  end if;

  select * into v_existing from feed.posts where id = p_id;
  if v_existing.id is not null then
    if v_existing.autor_id <> v_uid then raise exception 'Id en uso' using errcode = '23505'; end if;
    return feed.post_json(v_existing, v_uid);   -- reintento: misma respuesta
  end if;

  insert into feed.posts (id, autor_id, tipo, texto, media, visibilidad, club_id, compartido_de)
  values (p_id, v_uid, p_tipo, trim(p_texto), coalesce(p_media, '{}'), p_visibilidad, p_club_id, p_compartido_de)
  on conflict (id) do nothing;
  return api.get_post(p_id);
end;
$$;

-- ---------------------------------------------------------------- mark_read --
-- Antes: el recuento de no leídos se calculaba con la foto del inicio de la sentencia; si un
-- envío concurrente sumaba +1 justo antes, el UPDATE lo pisaba con un recuento sin ese
-- mensaje (actualización perdida → un mensaje nuevo sin aviso). Ahora se bloquea primero la
-- fila propia y se cuenta en una sentencia posterior, que ya ve todo lo confirmado.
-- Además el recuento parte del puntero efectivo (nunca de uno más antiguo).
create or replace function api.mark_read(p_conversation uuid, p_message_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_ptr uuid;
begin
  if not messaging.is_participant(p_conversation, v_uid) then
    raise exception 'No participas en esta conversación' using errcode = '42501';
  end if;
  select greatest(coalesce(cm.ultimo_leido_id, p_message_id), p_message_id) into v_ptr
    from messaging.conversation_members cm
   where cm.conversation_id = p_conversation and cm.user_id = v_uid
     for update;
  update messaging.conversation_members
     set ultimo_leido_id = v_ptr,
         no_leidos = (select count(*) from messaging.messages m
                       where m.conversation_id = p_conversation and m.id > v_ptr and m.remitente_id <> v_uid)
   where conversation_id = p_conversation and user_id = v_uid;
  perform realtime.send(jsonb_build_object('user_id', v_uid, 'message_id', v_ptr),
    'message.read', 'conversation:' || p_conversation::text, true);
end;
$$;

-- ------------------------------------------------------- particiones de mensajes --
-- 1) Dos ejecuciones simultáneas (cron + manual) chocaban con «relation already exists».
-- 2) Si alguna vez faltó la partición de un mes y sus mensajes cayeron en la partición por
--    defecto, crearla fallaba para siempre (la default tendría filas de ese rango). Ahora se
--    crean aparte, se mueven esas filas y se adjuntan, todo en la misma transacción.
create or replace function messaging.ensure_partitions(p_from date, p_months int)
returns int language plpgsql security definer set search_path = ''
as $$
declare
  v_start date := date_trunc('month', p_from)::date;
  v_m date;
  v_name text;
  v_lo uuid;
  v_hi uuid;
  v_created int;
  v_missing boolean := false;
  v_prev_timeout text := current_setting('lock_timeout');
begin
  for i in 0 .. p_months - 1 loop
    v_missing := v_missing or to_regclass('messaging.messages_'
      || to_char(v_start + make_interval(months => i), 'YYYY_MM')) is null;
  end loop;
  if not v_missing then return 0; end if;   -- caso habitual: nada que hacer, sin bloqueos

  perform pg_advisory_xact_lock(hashtextextended('messaging.ensure_partitions', 0));
  -- El DDL necesita bloqueos fuertes sobre messages_default y conversations, que los envíos
  -- de mensajes toman en otro orden. Para no provocar NUNCA un interbloqueo que aborte un
  -- envío, esperamos poco (100 ms, menos que deadlock_timeout): si hay que ceder, cede el
  -- mantenimiento, deshace su intento y lo repite unos milisegundos después.
  perform set_config('lock_timeout', '100ms', true);
  for attempt in 1 .. 100 loop
    begin
      v_created := 0;
      lock table messaging.messages_default in access exclusive mode;
      lock table messaging.conversations in share row exclusive mode;
      for i in 0 .. p_months - 1 loop
        v_m := (v_start + make_interval(months => i))::date;
        v_name := 'messages_' || to_char(v_m, 'YYYY_MM');
        v_lo := util.uuid_v7_floor(v_m::timestamptz);
        v_hi := util.uuid_v7_floor((v_m + interval '1 month')::timestamptz);
        if to_regclass('messaging.' || v_name) is null then
          execute format('create table messaging.%I (like messaging.messages including defaults including constraints)', v_name);
          execute format(
            'with moved as (delete from messaging.messages_default where id >= %L and id < %L returning *)
             insert into messaging.%I select * from moved', v_lo, v_hi, v_name);
          execute format('alter table messaging.messages attach partition messaging.%I for values from (%L) to (%L)',
            v_name, v_lo, v_hi);
          execute format('alter table messaging.%I enable row level security', v_name);
          v_created := v_created + 1;
        end if;
      end loop;
      perform set_config('lock_timeout', v_prev_timeout, true);
      return v_created;
    exception when lock_not_available then
      perform pg_sleep(0.02 + random() * 0.1);
    end;
  end loop;
  perform set_config('lock_timeout', v_prev_timeout, true);
  raise exception 'No se pudieron crear las particiones por actividad continua; se reintentará' using errcode = '55P03';
end;
$$;
revoke execute on function messaging.ensure_partitions(date, int) from public, authenticated, anon;
grant execute on function messaging.ensure_partitions(date, int) to service_role;

-- ------------------------------------------------------------ borrar cuenta --
-- Al borrar sus mensajes, la vista previa del último mensaje (con su texto) seguía visible
-- para la otra persona y sus no leídos seguían contándolos. Se recalculan.
create or replace function api.delete_my_account(p_confirmacion text)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_convs uuid[];
begin
  if p_confirmacion is distinct from 'BORRAR MI CUENTA' then
    raise exception 'Confirmación incorrecta' using errcode = '22023';
  end if;
  -- Orden de bloqueo igual que send_message (socio → conversación): sin interbloqueos.
  -- Quien esté escribiéndonos ahora termina primero; quien llegue después ya no nos encuentra.
  perform 1 from identity.members where user_id = v_uid for update;
  select coalesce(array_agg(conversation_id order by conversation_id), '{}') into v_convs
    from messaging.conversation_members where user_id = v_uid;
  perform 1 from messaging.conversations where id = any (v_convs) order by id for update;

  delete from messaging.messages where remitente_id = v_uid;
  delete from moderation.reports where reporter_id = v_uid;
  delete from orientador.documents where user_id = v_uid;
  delete from auth.users where id = v_uid;

  update messaging.conversations c
     set ultimo_mensaje_id = l.id, ultimo_mensaje_en = l.created_at, ultimo_mensaje_preview = left(l.cuerpo, 140)
    from (select cv.id as conv, last.*
            from unnest(v_convs) cv(id)
            left join lateral (select m.id, m.created_at, m.cuerpo from messaging.messages m
                                where m.conversation_id = cv.id order by m.id desc limit 1) last on true) l
   where c.id = l.conv;
  update messaging.conversation_members cm
     set no_leidos = (select count(*) from messaging.messages m
                       where m.conversation_id = cm.conversation_id and m.remitente_id <> cm.user_id
                         and (cm.ultimo_leido_id is null or m.id > cm.ultimo_leido_id))
   where cm.conversation_id = any (v_convs);
end;
$$;
