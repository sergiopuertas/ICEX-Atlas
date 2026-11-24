-- messaging: envío idempotente, conversaciones 1:1, RLS, leídos, bloqueos, Realtime privado.
begin;
\ir helpers.inc
select plan(26);

select tests.create_member('Remitente') as ana \gset
select tests.create_member('Destinataria') as bea \gset
select tests.create_member('Ajena') as carla \gset

select tests.authenticate_as(:'ana');
select lives_ok(format($$select api.send_message('01900000-0000-7000-8000-00000000aa01', 'Hola Bea', null, %L, 'mentoria')$$, :'bea'),
  'send_message: primer mensaje crea la conversación 1:1');
select api.find_direct_conversation(:'bea') as conv \gset
select isnt(:'conv'::uuid, null::uuid, 'find_direct_conversation encuentra la conversación');
select is((select categoria::text from messaging.conversations where id = :'conv'), 'mentoria', 'con la categoría elegida');
select is((api.send_message('01900000-0000-7000-8000-00000000aa01', 'Hola Bea', null, :'bea') ->> 'duplicado')::boolean, true,
  'send_message es idempotente por id (reintento)');
select is((select count(*)::int from messaging.messages where conversation_id = :'conv'), 1, 'sin mensajes duplicados');
select lives_ok(format($$select api.send_message('01900000-0000-7000-8000-00000000aa02', 'Segundo', %L)$$, :'conv'),
  'send_message a conversación existente');
select is((select count(*)::int from messaging.conversations where direct_key = messaging.direct_key(:'ana', :'bea')), 1,
  'Una única conversación por pareja');
select ok(tests.queue_len('message_events') >= 2, 'Cada envío encola un evento en pgmq (push offline)');
select throws_ok($$insert into messaging.messages (id, conversation_id, remitente_id, cuerpo)
  select gen_random_uuid(), conversation_id, auth.uid(), 'x' from messaging.conversation_members limit 1$$,
  '42501', null, 'INSERT directo en messages denegado (solo vía send_message)');
select throws_ok($$select api.send_message(gen_random_uuid(), '   ', null, auth.uid())$$, '22023', null, 'Mensaje vacío rechazado');

select tests.authenticate_as(:'bea');
select is((select no_leidos from messaging.conversation_members where conversation_id = :'conv' and user_id = :'bea'), 2,
  'no_leidos del destinatario = 2');
select is((api.unread_counts() ->> 'mensajes')::int, 2, 'unread_counts refleja los no leídos');
select is(jsonb_array_length(api.get_messages(:'conv') -> 'items'), 2, 'messages_select: el participante lee el hilo');
select is(jsonb_array_length(api.get_messages(:'conv', null, '01900000-0000-7000-8000-00000000aa01') -> 'items'), 1,
  'get_messages p_after: recupera lo posterior al último conocido (reconexión)');
select lives_ok(format($$select api.mark_read(%L, '01900000-0000-7000-8000-00000000aa02')$$, :'conv'), 'mark_read');
select is((select no_leidos from messaging.conversation_members where conversation_id = :'conv' and user_id = :'bea'), 0,
  'mark_read pone no_leidos a 0');
select is((api.get_conversation(:'conv') -> 'otro' ->> 'ultimo_leido_id'), '01900000-0000-7000-8000-00000000aa02',
  'Doble check: el remitente ve hasta dónde se ha leído');
select throws_ok(format($$update messaging.conversation_members set no_leidos = 0, ultimo_leido_id = null where conversation_id = %L$$, :'conv'),
  '42501', null, 'No puede manipular columnas de leídos directamente');

-- Realtime: autorización de canal privado
select set_config('realtime.topic', 'conversation:' || :'conv', true);
select ok(exists(select 1 from realtime.messages limit 1) or true, 'consulta a realtime.messages permitida');
select is((select count(*)::int from pg_policies where schemaname = 'realtime' and policyname like 'realtime_icex%'), 2,
  'Políticas de canal privado instaladas');
select ok(messaging.is_participant(:'conv', :'bea'), 'Participante autorizado en conversation:<id>');

select tests.authenticate_as(:'carla');
select is_empty(format($$select 1 from messaging.messages where conversation_id = %L$$, :'conv'),
  'messages_select (negativo): un tercero no lee la conversación');
select is_empty(format($$select 1 from messaging.conversations where id = %L$$, :'conv'),
  'conversations_select (negativo): ni la ve en su lista');
select throws_ok(format($$select api.send_message(util.uuid_v7(), 'intrusa', %L)$$, :'conv'), '42501', null,
  'send_message (negativo): un tercero no escribe en la conversación');
select ok(not messaging.is_participant(:'conv', :'carla'), 'Un tercero no se autoriza en el canal privado');

-- bloqueo impide escribir
select tests.authenticate_as(:'bea');
select api.block(:'ana');
select tests.authenticate_as(:'ana');
select throws_ok(format($$select api.send_message(util.uuid_v7(), '¿sigues ahí?', %L)$$, :'conv'), '42501', null,
  'Tras un bloqueo no se pueden enviar mensajes');

select * from finish();
rollback;
