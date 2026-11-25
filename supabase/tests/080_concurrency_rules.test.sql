-- Reglas que protegen frente a envíos fuera de orden y carreras (ver supabase/stress/).
-- Las carreas reales (muchas conexiones a la vez) se prueban en supabase/stress/concurrency.py;
-- aquí se fijan las reglas deterministas que las hacen seguras.
begin;
\ir helpers.inc
select plan(33);

select tests.create_member('Ana') as ana \gset
select tests.create_member('Bea') as bea \gset
select tests.create_member('Carla') as carla \gset

-- ---------------------------------------------------------- ids de mensaje ---
select tests.authenticate_as(:'ana');
select throws_ok(format($$select api.send_message(gen_random_uuid(), 'hola', null, %L)$$, :'bea'), '22023', null,
  'send_message rechaza ids que no son UUID v7');
select throws_ok(format($$select api.send_message(util.uuid_v7(now() + interval '1 day'), 'hola', null, %L)$$, :'bea'),
  '22023', null, 'send_message rechaza ids con fecha futura');
select lives_ok(format($$select api.send_message(util.uuid_v7(now() + interval '1 minute'), 'reloj adelantado', null, %L)$$, :'carla'),
  'send_message tolera un reloj ligeramente adelantado');

-- --------------------------------------------------- envíos fuera de orden ---
-- Ana escribe sin cobertura (id antiguo); Bea responde dos veces; Ana lee y luego se envía lo antiguo.
select util.uuid_v7(now() - interval '10 minutes') as antiguo \gset
select tests.authenticate_as(:'bea');
select (api.send_message(util.uuid_v7(now() - interval '20 minutes'), 'hola Ana', null, :'ana') ->> 'conversation_id') as conv \gset
select util.uuid_v7(now() - interval '1 minute') as b1 \gset
select util.uuid_v7() as b2 \gset
select api.send_message(:'b1', 'respuesta 1', :'conv');
select api.send_message(:'b2', 'respuesta 2', :'conv');
select tests.authenticate_as(:'ana');
select api.mark_read(:'conv', :'b2');
select api.send_message(:'antiguo', 'escrito sin cobertura', :'conv');

select tests.clear_authentication();
select is((select ultimo_mensaje_id from messaging.conversations where id = :'conv'), :'b2'::uuid,
  'el último mensaje no retrocede con un envío retrasado');
select is((select ultimo_leido_id from messaging.conversation_members where conversation_id = :'conv' and user_id = :'ana'),
  :'b2'::uuid, 'el puntero de leído del remitente no retrocede');
select is((select no_leidos from messaging.conversation_members where conversation_id = :'conv' and user_id = :'ana'), 0,
  'el remitente sigue con 0 no leídos');
select is((select no_leidos from messaging.conversation_members where conversation_id = :'conv' and user_id = :'bea'), 1,
  'el mensaje que llega tarde cuenta como no leído para la destinataria');

-- Si Bea escribe algo nuevo DESPUÉS de que Ana envíe lo antiguo, Ana lo ve como no leído.
select tests.authenticate_as(:'bea');
select api.send_message(util.uuid_v7(), 'nuevo', :'conv');
select tests.clear_authentication();
select is((select no_leidos from messaging.conversation_members where conversation_id = :'conv' and user_id = :'ana'), 1,
  'lo recibido después cuenta como no leído');

-- ---------------------------------------------------- socio que ya no está ---
select tests.authenticate_as(:'ana');
select throws_ok($$select api.follow('00000000-0000-4000-8000-000000000000')$$, 'P0002', null,
  'seguir a alguien que no es socio da «no encontrado», no un error de clave ajena');
select throws_ok($$select api.send_message(util.uuid_v7(), 'hola', null, '00000000-0000-4000-8000-000000000000')$$, '42501', null,
  'escribir a alguien que no es socio se rechaza de forma controlada');

-- ---------------------------------------------- notificaciones agrupadas ---
select util.uuid_v7() as post \gset
select api.create_post(:'post', 'post para agrupar');
select tests.authenticate_as(:'bea');
select api.recommend(:'post');
select api.unrecommend(:'post');
select api.recommend(:'post');
select tests.authenticate_as(:'carla');
select api.recommend(:'post');
select tests.clear_authentication();
select is((select count(*)::int from notifications.notifications where user_id = :'ana' and group_key = 'reco:' || :'post' and not leido),
  1, 'una sola notificación agrupada sin leer por post');
select is((select total from notifications.notifications where user_id = :'ana' and group_key = 'reco:' || :'post' and not leido),
  2, 'el mismo actor repitiendo no infla el total');
select is((select actor_ids[1] from notifications.notifications where user_id = :'ana' and group_key = 'reco:' || :'post' and not leido),
  :'carla'::uuid, 'el actor más reciente aparece primero');

-- ------------------------------------------------- particiones de mensajes ---
select tests.clear_authentication();
select util.uuid_v7('2031-03-15 10:00+00') as futuro \gset
insert into messaging.messages (id, conversation_id, remitente_id, cuerpo) values (:'futuro', :'conv', :'ana', 'cayó en default');
select is(messaging.ensure_partitions('2031-03-01', 1), 1,
  'ensure_partitions crea el mes aunque la partición por defecto tenga filas de ese rango');
select is((select tableoid::regclass::text from messaging.messages where id = :'futuro'), 'messaging.messages_2031_03',
  'las filas se mueven a su partición');
select is(messaging.ensure_partitions('2031-03-01', 1), 0, 'ensure_partitions es idempotente');
delete from messaging.messages where id = :'futuro';

-- ------------------------------------------------------------ borrar cuenta ---
select tests.authenticate_as(:'carla');
select (api.send_message(util.uuid_v7(), 'texto privado de Carla', null, :'bea') ->> 'conversation_id') as conv_cb \gset
select api.delete_my_account('BORRAR MI CUENTA');
select tests.clear_authentication();
select is((select ultimo_mensaje_preview from messaging.conversations where id = :'conv_cb'), null,
  'al borrar la cuenta no queda la vista previa de su último mensaje');
select is((select no_leidos from messaging.conversation_members where conversation_id = :'conv_cb' and user_id = :'bea'), 0,
  'ni cuentan como no leídos sus mensajes borrados');

-- ------------------------------------- mapa y «cerca de ti» (SECURITY DEFINER) ---
-- Pasaron a definer por rendimiento: aplican ellas mismas los filtros de la RLS.
select tests.create_member('Visible Ushuaia') as vis \gset
select tests.create_member('Oculta Ushuaia') as ocu \gset
select tests.create_member('Bloqueadora Ushuaia') as blo \gset
select tests.create_member('Baja Ushuaia') as baja \gset
select tests.authenticate_as(:'vis');
select api.update_my_profile(p_lat => -54.80, p_lng => -68.30, p_ciudad => 'Ushuaia');
select tests.authenticate_as(:'ocu');
select api.update_my_profile(p_lat => -54.80, p_lng => -68.31, p_ciudad => 'Ushuaia');
select api.set_privacy('{"ubicacion": "solo_yo"}'::jsonb);
select tests.authenticate_as(:'blo');
select api.update_my_profile(p_lat => -54.81, p_lng => -68.30, p_ciudad => 'Ushuaia');
select api.block(:'ana');
select tests.authenticate_as(:'baja');
select api.update_my_profile(p_lat => -54.80, p_lng => -68.29, p_ciudad => 'Ushuaia');
select tests.clear_authentication();
select identity.revoke_member(:'baja', 'test');

select tests.authenticate_as(:'ana');
select is((select array_agg(x ->> 'user_id') from jsonb_array_elements(api.alumni_near(-54.80, -68.30, 25)) x),
  array[:'vis'], 'alumni_near: solo quien comparte ubicación, sin bloqueos ni bajas');
select is((api.map_clusters(14, -68.40, -54.90, -68.20, -54.70, null, false) ->> 'total')::int, 1,
  'map_clusters: mismos filtros (visibilidad, bloqueos, bajas)');
select tests.authenticate_as(:'ocu');
select is((api.map_clusters(14, -68.40, -54.90, -68.20, -54.70, null, false) ->> 'total')::int, 3,
  'map_clusters: cada uno se ve a sí mismo aunque oculte su ubicación (y el bloqueo es solo con Ana)');
select tests.authenticate_as(:'baja');
select throws_ok($$select api.alumni_near(-54.80, -68.30)$$, '42501', null, 'alumni_near exige ser socio activo');
select throws_ok($$select api.map_clusters(2, -180, -85, 180, 85)$$, '42501', null, 'map_clusters exige ser socio activo');
select tests.as_anon();
select throws_ok($$select api.map_clusters(2, -180, -85, 180, 85)$$, '42501', null, 'map_clusters: anónimo rechazado');

-- ------------------------------------------------------ directorio: privacidad ---
select tests.create_member('Discreta Zuloaga') as disc \gset
select tests.authenticate_as(:'disc');
select api.update_my_profile(p_empresa => 'Empresa Secreta Xyzzy', p_cargo => 'Cargo Visible Plugh');
select api.set_privacy('{"empresa": "solo_yo"}'::jsonb);
select tests.authenticate_as(:'ana');
select is((api.search_directory('xyzzy') ->> 'total')::int, 0,
  'search_directory: no se encuentra a nadie por un dato que ha ocultado');
select is((api.search_directory('plugh') ->> 'total')::int, 1,
  'search_directory: sí por los datos visibles');
select is((api.search_directory('zuloaga plugh') ->> 'total')::int, 1, 'search_directory: varios términos a la vez');
select is((api.search_directory('Baja Ushuaia') ->> 'total')::int, 0, 'search_directory: las bajas no aparecen');

-- --------------------------------------------- agregados en caché (mapa / cifras) ---
select tests.create_member('Solitaria Kerguelen') as sola \gset
select tests.authenticate_as(:'sola');
select api.update_my_profile(p_lat => -49.35, p_lng => 70.22, p_ciudad => 'Port-aux-Français');
select tests.clear_authentication();
select profiles.refresh_aggregates();
select count(*)::int as activos from profiles.profiles p join identity.members m using (user_id) where m.status = 'active' \gset
-- (Disc no tiene bloqueos: en celdas de varias personas la caché no descuenta bloqueos, solo en las de una.)
select tests.authenticate_as(:'disc');
select (api.map_clusters(2, -180, -85, 180, 85) ->> 'total')::int as total_cache \gset
select tests.clear_authentication();
update profiles.aggregates_meta set refreshed_at = now() - interval '1 hour';
select tests.authenticate_as(:'disc');
select is((api.map_clusters(2, -180, -85, 180, 85) ->> 'total')::int, :total_cache,
  'mapa mundial: la caché da el mismo total que el cálculo en vivo');
select is((api.community_stats() ->> 'alumni')::int, :activos, 'community_stats en vivo cuando la caché ha caducado');
select tests.clear_authentication();
update profiles.aggregates_meta set refreshed_at = now();
select (community_stats ->> 'alumni')::int as alumni_cache from profiles.aggregates_meta \gset
-- Tras refrescar, oculta su ubicación: su celda (de una sola persona) ya no debe mostrarla.
select tests.authenticate_as(:'sola');
select api.set_privacy('{"ubicacion": "solo_yo"}'::jsonb);
select tests.authenticate_as(:'ana');
select ok(not exists (select 1 from jsonb_array_elements(api.map_clusters(2, -180, -85, 180, 85) -> 'clusters') c
                       where c -> 'alumni' ->> 'user_id' = :'sola'),
  'caché: una celda de una sola persona se comprueba en vivo (no expone a quien ya se ocultó)');
select is((api.community_stats() ->> 'alumni')::int, :alumni_cache,
  'community_stats sale de la caché cuando está fresca');
select throws_ok($$select * from profiles.aggregates_meta$$, '42501', null, 'la caché no es legible por los clientes');

select * from finish();
rollback;
