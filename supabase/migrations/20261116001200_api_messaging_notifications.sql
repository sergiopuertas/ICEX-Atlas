-- =============================================================================
-- ICEX Atlas · 1200 · API: mensajería y notificaciones
-- =============================================================================

create or replace function messaging.message_json(m messaging.messages)
returns jsonb language sql immutable set search_path = ''
as $$
  select jsonb_build_object('id', m.id, 'conversation_id', m.conversation_id, 'remitente_id', m.remitente_id,
                            'cuerpo', m.cuerpo, 'created_at', m.created_at);
$$;
grant execute on function messaging.message_json(messaging.messages) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- send_message: UNA transacción que
--   1) valida membresía (remitente y destinatario) y bloqueos,
--   2) crea la conversación 1:1 si no existe (categoría elegida),
--   3) inserta el mensaje de forma idempotente por id (UUIDv7 del cliente),
--   4) actualiza último mensaje y no leídos de los demás participantes,
--   5) encola el evento en pgmq (push a destinatarios sin conexión).
-- El trigger messaging.broadcast_message publica por Realtime Broadcast (canal privado).
-- security definer: escribe filas de otros participantes (no_leidos) y en la cola.
-- -----------------------------------------------------------------------------
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
  v_inserted boolean := false;
begin
  if p_id is null or v_cuerpo = '' then
    raise exception 'Mensaje vacío' using errcode = '22023';
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
    if not identity.is_member_id(p_to) then
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
  v_inserted := v_msg.id is not null;
  if not v_inserted then
    select * into v_msg from messaging.messages where id = p_id;
    return messaging.message_json(v_msg) || jsonb_build_object('duplicado', true);
  end if;

  update messaging.conversations
     set ultimo_mensaje_en = v_msg.created_at, ultimo_mensaje_id = v_msg.id,
         ultimo_mensaje_preview = left(v_cuerpo, 140),
         categoria = coalesce(p_categoria, categoria)
   where id = v_conv;
  update messaging.conversation_members
     set no_leidos = case when user_id = v_uid then 0 else no_leidos + 1 end,
         ultimo_leido_id = case when user_id = v_uid then v_msg.id else ultimo_leido_id end,
         archivado = false
   where conversation_id = v_conv;

  perform pgmq.send('message_events', jsonb_build_object(
    'message_id', v_msg.id, 'conversation_id', v_conv, 'remitente_id', v_uid,
    'destinatarios', (select coalesce(jsonb_agg(cm.user_id), '[]'::jsonb) from messaging.conversation_members cm
                       where cm.conversation_id = v_conv and cm.user_id <> v_uid and not cm.silenciado)));

  -- Aviso de no leídos al canal personal de cada destinatario.
  perform realtime.send(jsonb_build_object('conversation_id', v_conv, 'message_id', v_msg.id),
            'conversation.updated', 'user:' || cm.user_id::text, true)
     from messaging.conversation_members cm where cm.conversation_id = v_conv;

  return messaging.message_json(v_msg) || jsonb_build_object('duplicado', false);
end;
$$;

-- Conversación 1:1 existente con un socio (para el deep link mensajes?to=<perfil>).
create or replace function api.find_direct_conversation(p_to uuid)
returns uuid language sql stable security invoker set search_path = ''
as $$
  select c.id from messaging.conversations c
   where c.direct_key = messaging.direct_key(identity.require_member(), p_to);
$$;

create or replace function api.list_conversations(
  p_categoria messaging.categoria default null, p_cursor text default null, p_limit int default 30)
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_limit int := least(greatest(coalesce(p_limit, 30), 1), 100);
  v_items jsonb;
begin
  select coalesce(jsonb_agg(x.j order by x.ts desc, x.id desc), '[]'::jsonb) into v_items
  from (
    select c.id, coalesce(c.ultimo_mensaje_en, c.created_at) as ts,
           jsonb_build_object(
             'id', c.id, 'categoria', c.categoria, 'tipo', c.tipo,
             'ultimo_mensaje_en', c.ultimo_mensaje_en, 'ultimo_mensaje_preview', c.ultimo_mensaje_preview,
             'ultimo_mensaje_id', c.ultimo_mensaje_id,
             'no_leidos', me.no_leidos, 'silenciado', me.silenciado,
             'otro', (select profiles.card(pr, v_uid, false) || jsonb_build_object('ultimo_leido_id', o.ultimo_leido_id)
                        from messaging.conversation_members o join profiles.profiles pr on pr.user_id = o.user_id
                       where o.conversation_id = c.id and o.user_id <> v_uid limit 1),
             '_cursor', util.encode_cursor(coalesce(c.ultimo_mensaje_en, c.created_at), c.id)) as j
      from messaging.conversation_members me
      join messaging.conversations c on c.id = me.conversation_id
     where me.user_id = v_uid and not me.archivado
       and (p_categoria is null or c.categoria = p_categoria)
       and (p_cursor is null or (coalesce(c.ultimo_mensaje_en, c.created_at), c.id)
                                 < (util.cursor_ts(p_cursor), util.cursor_id(p_cursor)))
     order by coalesce(c.ultimo_mensaje_en, c.created_at) desc, c.id desc
     limit v_limit) x;
  return jsonb_build_object('items', v_items,
    'total_no_leidos', (select coalesce(sum(no_leidos), 0) from messaging.conversation_members where user_id = v_uid),
    'next_cursor', case when jsonb_array_length(v_items) = v_limit then v_items -> (v_limit - 1) ->> '_cursor' end);
end;
$$;

create or replace function api.get_conversation(p_conversation uuid)
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v jsonb;
begin
  select jsonb_build_object('id', c.id, 'categoria', c.categoria, 'tipo', c.tipo,
           'otro', (select profiles.card(pr, v_uid, false) || jsonb_build_object('ultimo_leido_id', o.ultimo_leido_id)
                      from messaging.conversation_members o join profiles.profiles pr on pr.user_id = o.user_id
                     where o.conversation_id = c.id and o.user_id <> v_uid limit 1),
           'silenciado', me.silenciado)
    into v
    from messaging.conversations c
    join messaging.conversation_members me on me.conversation_id = c.id and me.user_id = v_uid
   where c.id = p_conversation;
  if v is null then raise exception 'Conversación no disponible' using errcode = 'P0002'; end if;
  return v;
end;
$$;

-- Mensajes por keyset sobre el id (UUIDv7 = orden temporal).
--   p_before: página hacia atrás (scroll).  p_after: recuperar tras reconectar.
create or replace function api.get_messages(
  p_conversation uuid, p_before uuid default null, p_after uuid default null, p_limit int default 50)
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_limit int := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_items jsonb;
begin
  if p_after is not null then
    select coalesce(jsonb_agg(messaging.message_json(m) order by m.id), '[]'::jsonb) into v_items
      from (select * from messaging.messages m
             where m.conversation_id = p_conversation and m.id > p_after
             order by m.id limit v_limit) m;
  else
    select coalesce(jsonb_agg(messaging.message_json(m) order by m.id), '[]'::jsonb) into v_items
      from (select * from messaging.messages m
             where m.conversation_id = p_conversation
               and (p_before is null or m.id < p_before)
             order by m.id desc limit v_limit) m;
  end if;
  return jsonb_build_object('items', v_items, 'has_more', jsonb_array_length(v_items) = v_limit);
end;
$$;

-- Leído (doble check): actualiza último leído, pone no_leidos a 0 y avisa por Realtime.
-- definer: el socio solo tiene UPDATE de silenciado/archivado en su fila.
create or replace function api.mark_read(p_conversation uuid, p_message_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  if not messaging.is_participant(p_conversation, v_uid) then
    raise exception 'No participas en esta conversación' using errcode = '42501';
  end if;
  update messaging.conversation_members
     set ultimo_leido_id = greatest(coalesce(ultimo_leido_id, p_message_id), p_message_id),
         no_leidos = (select count(*) from messaging.messages m
                       where m.conversation_id = p_conversation and m.id > p_message_id and m.remitente_id <> v_uid)
   where conversation_id = p_conversation and user_id = v_uid;
  perform realtime.send(jsonb_build_object('user_id', v_uid, 'message_id', p_message_id),
    'message.read', 'conversation:' || p_conversation::text, true);
end;
$$;

create or replace function api.set_conversation_category(p_conversation uuid, p_categoria messaging.categoria)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  if not messaging.is_participant(p_conversation, v_uid) then
    raise exception 'No participas en esta conversación' using errcode = '42501';
  end if;
  update messaging.conversations set categoria = p_categoria where id = p_conversation;
end;
$$;

create or replace function api.mute_conversation(p_conversation uuid, p_silenciado boolean)
returns void language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  update messaging.conversation_members set silenciado = p_silenciado
   where conversation_id = p_conversation and user_id = v_uid;
end;
$$;

-- ---------------------------------------------------------- notificaciones ----
create or replace function api.list_notifications(p_cursor text default null, p_limit int default 30)
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_limit int := least(greatest(coalesce(p_limit, 30), 1), 100);
  v_items jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', n.id, 'tipo', n.tipo, 'total', n.total, 'payload', n.payload, 'leido', n.leido,
           'created_at', n.created_at, 'updated_at', n.updated_at,
           'actores', (select coalesce(jsonb_agg(profiles.card(pr, v_uid, false)), '[]'::jsonb)
                         from profiles.profiles pr where pr.user_id = any (n.actor_ids[1:3])),
           '_cursor', util.encode_cursor(n.updated_at, n.id))
         order by n.updated_at desc, n.id desc), '[]'::jsonb)
    into v_items
    from (select * from notifications.notifications n
           where n.user_id = v_uid
             and (p_cursor is null or (n.updated_at, n.id) < (util.cursor_ts(p_cursor), util.cursor_id(p_cursor)))
           order by n.updated_at desc, n.id desc limit v_limit) n;
  return jsonb_build_object('items', v_items,
    'no_leidas', (select count(*) from notifications.notifications where user_id = v_uid and not leido),
    'next_cursor', case when jsonb_array_length(v_items) = v_limit then v_items -> (v_limit - 1) ->> '_cursor' end);
end;
$$;

create or replace function api.mark_notifications_read(p_ids uuid[] default null)
returns int language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member(); v_n int;
begin
  update notifications.notifications set leido = true
   where user_id = v_uid and not leido and (p_ids is null or id = any (p_ids));
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

create or replace function api.unread_counts()
returns jsonb language sql stable security invoker set search_path = ''
as $$
  select jsonb_build_object(
    'mensajes', (select coalesce(sum(no_leidos), 0) from messaging.conversation_members
                  where user_id = identity.require_member() and not silenciado),
    'notificaciones', (select count(*) from notifications.notifications
                        where user_id = (select auth.uid()) and not leido));
$$;

create or replace function api.get_notification_preferences()
returns jsonb language sql stable security invoker set search_path = ''
as $$
  select to_jsonb(p) - 'user_id' from notifications.preferences p where p.user_id = identity.require_member();
$$;

create or replace function api.update_notification_preferences(p_prefs jsonb)
returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  insert into notifications.preferences (user_id) values (v_uid) on conflict do nothing;
  update notifications.preferences set
    push_mensajes = coalesce((p_prefs ->> 'push_mensajes')::boolean, push_mensajes),
    push_social = coalesce((p_prefs ->> 'push_social')::boolean, push_social),
    push_eventos = coalesce((p_prefs ->> 'push_eventos')::boolean, push_eventos),
    push_novedades = coalesce((p_prefs ->> 'push_novedades')::boolean, push_novedades),
    email_novedades = coalesce((p_prefs ->> 'email_novedades')::boolean, email_novedades),
    email_resumen_semanal = coalesce((p_prefs ->> 'email_resumen_semanal')::boolean, email_resumen_semanal),
    consentimiento_comunicaciones = coalesce((p_prefs ->> 'consentimiento_comunicaciones')::boolean, consentimiento_comunicaciones),
    consentimiento_at = case when (p_prefs ->> 'consentimiento_comunicaciones') is not null then now() else consentimiento_at end
  where user_id = v_uid;
  -- Sin consentimiento no hay emails.
  update notifications.preferences set email_novedades = false, email_resumen_semanal = false
   where user_id = v_uid and not consentimiento_comunicaciones;
  return api.get_notification_preferences();
end;
$$;

create or replace function api.register_push_token(p_token text, p_plataforma notifications.plataforma)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  -- Un token pertenece a un único dispositivo: si cambia de usuario, se reasigna.
  insert into notifications.push_tokens (token, user_id, plataforma) values (p_token, v_uid, p_plataforma)
  on conflict (token) do update set user_id = excluded.user_id, plataforma = excluded.plataforma, updated_at = now();
end;
$$;

create or replace function api.unregister_push_token(p_token text)
returns void language plpgsql security invoker set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  delete from notifications.push_tokens where token = p_token and user_id = v_uid;
end;
$$;
