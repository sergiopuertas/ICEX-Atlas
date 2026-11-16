-- identity: hooks de Auth, membresía y bloqueo total de no verificados.
begin;
\ir helpers.inc
select plan(31);

-- ------------------------------------------------------------ hooks ----------
select is(identity.before_user_created(jsonb_build_object('user', jsonb_build_object(
  'app_metadata', jsonb_build_object('provider', 'custom:icex-alumni'),
  'user_metadata', jsonb_build_object('custom_claims', jsonb_build_object('icex_member_verified', true))))),
  '{}'::jsonb, 'before_user_created acepta socio verificado por el IdP');

select is(identity.before_user_created(jsonb_build_object('user', jsonb_build_object(
  'app_metadata', jsonb_build_object('provider', 'custom:icex-alumni'),
  'user_metadata', jsonb_build_object('custom_claims', jsonb_build_object('icex_member_verified', false))))) -> 'error' ->> 'message',
  'icex_member_not_verified', 'before_user_created rechaza claim false');

select is(identity.before_user_created(jsonb_build_object('user', jsonb_build_object(
  'app_metadata', jsonb_build_object('provider', 'custom:icex-alumni'),
  'user_metadata', '{}'::jsonb))) -> 'error' ->> 'http_code', '403', 'before_user_created rechaza sin claim');

select is(identity.before_user_created(jsonb_build_object('user', jsonb_build_object(
  'app_metadata', jsonb_build_object('provider', 'email'),
  'user_metadata', jsonb_build_object('icex_member_verified', true)))) -> 'error' ->> 'message',
  'icex_member_not_verified', 'before_user_created rechaza otros proveedores (email, etc.)');

select tests.create_member('Socia Activa') as socia \gset
select tests.create_unverified('No Verificado') as nover \gset
select tests.create_member('Admin Test', 'admin') as admin \gset

select ok(exists(select 1 from identity.members where user_id = :'socia' and status = 'active'),
  'El alta verificada crea la membresía activa');
select ok(exists(select 1 from profiles.profiles where user_id = :'socia' and nombre = 'Socia Activa'),
  'y el perfil inicial con el nombre del IdP');
select ok(not exists(select 1 from identity.members where user_id = :'nover'),
  'Un usuario sin claim no obtiene membresía');

select is(identity.custom_access_token(jsonb_build_object('user_id', :'socia', 'claims', '{"role":"authenticated"}'::jsonb))
  -> 'claims' ->> 'user_role', 'socio', 'custom_access_token añade user_role');
select is(identity.custom_access_token(jsonb_build_object('user_id', :'admin', 'claims', '{}'::jsonb))
  -> 'claims' ->> 'user_role', 'admin', 'custom_access_token: rol admin');
select is(identity.custom_access_token(jsonb_build_object('user_id', :'nover', 'claims', '{}'::jsonb))
  -> 'error' ->> 'http_code', '403', 'custom_access_token rechaza a quien no es socio');

-- ------------------------------------- no verificado: no lee ni escribe nada -
select tests.authenticate_as(:'nover');
select throws_ok($$select api.me()$$, '42501', null, 'No verificado: api.me() denegado');
select throws_ok($$select api.get_feed()$$, '42501', null, 'No verificado: api.get_feed() denegado');
select throws_ok($$select api.search_directory('Ana')$$, '42501', null, 'No verificado: directorio denegado');
select throws_ok($$select api.list_conversations()$$, '42501', null, 'No verificado: mensajes denegados');
select throws_ok($$select api.send_message(gen_random_uuid(), 'hola', null, (select user_id from identity.members limit 1))$$,
  '42501', null, 'No verificado: no puede enviar mensajes');
select throws_ok($$select api.create_post(gen_random_uuid(), 'hola')$$, '42501', null, 'No verificado: no puede publicar');
select throws_ok($$select api.map_clusters(2, -180, -85, 180, 85)$$, '42501', null, 'No verificado: mapa denegado');
select is_empty($$select 1 from profiles.profiles$$, 'No verificado: 0 perfiles visibles');
select is_empty($$select 1 from feed.posts$$, 'No verificado: 0 publicaciones visibles');
select is_empty($$select 1 from social.follows$$, 'No verificado: 0 seguimientos visibles');
select is_empty($$select 1 from clubs.clubs$$, 'No verificado: 0 clubs visibles');
select is_empty($$select 1 from config.app_config$$, 'No verificado: 0 flags visibles');
select is_empty($$select 1 from identity.members$$, 'No verificado: no ve membresías');
select throws_ok(format($$insert into social.follows (seguidor_id, seguido_id) values (%L, %L)$$, :'nover', :'socia'),
  '42501', null, 'No verificado: INSERT directo en follows bloqueado por RLS');
select throws_ok(format($$insert into feed.posts (autor_id, texto) values (%L, 'x')$$, :'nover'),
  '42501', null, 'No verificado: INSERT directo en posts bloqueado por RLS');

-- ------------------------------------------------------ anon ------------------
select tests.as_anon();
select throws_ok($$select api.me()$$, '42501', null, 'anon no puede ejecutar la API');
select throws_ok($$select * from profiles.profiles$$, '42501', null, 'anon no tiene acceso a tablas de módulo');

-- ------------------------------------------------ socio: members --------------
select tests.authenticate_as(:'socia');
select is((select count(*)::int from identity.members), 1, 'Un socio solo ve su propia fila de members');
select is((api.me() ->> 'role'), 'socio', 'api.me() devuelve el rol');

-- ------------------------------------------------ baja: revocación ------------
select tests.clear_authentication();
select identity.revoke_member(:'socia', 'test');
select tests.authenticate_as(:'socia');
select throws_ok($$select api.me()$$, '42501', null, 'Socio dado de baja: pierde el acceso al instante (RLS)');
select tests.clear_authentication();
select is(identity.custom_access_token(jsonb_build_object('user_id', :'socia', 'claims', '{}'::jsonb))
  -> 'error' ->> 'message', 'icex_member_not_active', 'y no puede refrescar su JWT');

select * from finish();
rollback;
