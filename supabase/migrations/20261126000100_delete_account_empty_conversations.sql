-- Borrar la cuenta no deja conversaciones vacías.
-- Si los dos participantes de una conversación borran su cuenta, la conversación se quedaba sin
-- miembros (solo metadatos: categoría y fechas). Lo detectó la prueba de carga (scripts/load/carga.py),
-- que borra cientos de cuentas que se han escrito entre sí. Ahora se borra al irse el último.
-- Es la misma función de 20261124000100 con una sentencia más al final.
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

  delete from messaging.conversations c
   where c.id = any (v_convs)
     and not exists (select 1 from messaging.conversation_members cm where cm.conversation_id = c.id);
end;
$$;

-- Restos de cuentas borradas antes de este cambio.
delete from messaging.conversations c
 where not exists (select 1 from messaging.conversation_members cm where cm.conversation_id = c.id);
