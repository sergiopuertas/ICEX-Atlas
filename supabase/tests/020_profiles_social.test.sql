-- profiles + social: RLS (positivo/negativo), privacidad por campo, contadores, bloqueos.
begin;
\ir helpers.inc
select plan(30);

select tests.create_member('Ana Test') as ana \gset
select tests.create_member('Bea Test') as bea \gset
select tests.create_member('Carlos Test') as carlos \gset
select tests.create_member('Admin Test', 'admin') as admin \gset

-- --------------------------------------------------------------- profiles ----
select tests.authenticate_as(:'ana');
select ok((select count(*) from profiles.profiles where user_id in (:'bea', :'carlos')) = 2,
  'profiles_select_members: un socio ve los perfiles de otros socios');
select lives_ok($$select api.update_my_profile(p_cargo => 'Export Manager', p_empresa => 'ACS', p_ciudad => 'Lima',
  p_lat => -12.0464, p_lng => -77.0428)$$, 'profiles_update_own: edita su perfil');
select is((select cargo from profiles.profiles where user_id = :'ana'), 'Export Manager', 'el cambio se guarda');
select is((select round(extensions.st_y(ubicacion::extensions.geometry)::numeric, 2) from profiles.profiles where user_id = :'ana'),
  -12.05, 'la ubicación se redondea a nivel de ciudad (privacidad)');
update profiles.profiles set cargo = 'Hackeado' where user_id = :'bea';
select isnt((select cargo from profiles.profiles where user_id = :'bea'), 'Hackeado',
  'profiles_update_own (negativo): no puede editar el perfil de otro');
select throws_ok($$update profiles.profiles set seguidores_count = 99999$$, '42501', null,
  'No puede tocar contadores (sin privilegio de columna)');
select throws_ok($$select api.update_my_profile(p_foto_path => 'otra-persona/foto.jpg')$$, '22023', null,
  'La foto debe estar en su propia carpeta');

-- privacidad por campo
select tests.authenticate_as(:'bea');
select lives_ok($$select api.set_privacy('{"empresa":"seguidores","bio":"solo_yo"}'::jsonb)$$, 'set_privacy acepta valores válidos');
select throws_ok($$select api.set_privacy('{"empresa":"todo_el_mundo"}'::jsonb)$$, '22023', null, 'set_privacy rechaza valores inválidos');
select tests.clear_authentication();
update profiles.profiles set empresa = 'Repsol', bio = 'secreta' where user_id = :'bea';
select tests.authenticate_as(:'ana');
select is(api.get_profile(p_user => :'bea') ->> 'empresa', null, 'Campo "seguidores": oculto a quien no sigue');
select is(api.get_profile(p_user => :'bea') ->> 'bio', null, 'Campo "solo_yo": oculto');
select lives_ok(format($$select api.follow(%L)$$, :'bea'), 'follows_insert_own: seguir');
select is(api.get_profile(p_user => :'bea') ->> 'empresa', 'Repsol', 'Campo "seguidores": visible al seguir');
select is(api.get_profile(p_user => :'bea') ->> 'bio', null, 'Campo "solo_yo": sigue oculto al seguir');
select tests.authenticate_as(:'bea');
select is(api.get_profile(p_user => :'bea') ->> 'bio', 'secreta', 'El dueño ve todos sus campos');

-- experiences
select lives_ok($$select api.upsert_experience(gen_random_uuid(), 'CESCE', 'Analista', '2020-01-01', '2022-06-01')$$,
  'experiences_write_own: añadir trayectoria');
select throws_ok(format($$insert into profiles.experiences (user_id, empresa, cargo, desde) values (%L, 'X', 'Y', '2020-01-01')$$, :'ana'),
  '42501', null, 'experiences_write_own (negativo): no puede escribir trayectoria ajena');

-- ----------------------------------------------------------------- social ----
select tests.authenticate_as(:'ana');
select is((select seguidores_count from profiles.profiles where user_id = :'bea'), 1, 'Trigger: seguidores_count +1');
select is((select siguiendo_count from profiles.profiles where user_id = :'ana'), 1, 'Trigger: siguiendo_count +1');
select lives_ok(format($$select api.follow(%L)$$, :'bea'), 'Seguir dos veces es idempotente');
select is((select seguidores_count from profiles.profiles where user_id = :'bea'), 1, 'sin doble conteo');
select throws_ok(format($$insert into social.follows (seguidor_id, seguido_id) values (%L, %L)$$, :'carlos', :'bea'),
  '42501', null, 'follows_insert_own (negativo): no puede crear un follow en nombre de otro');
select tests.authenticate_as(:'carlos');
delete from social.follows where seguidor_id = :'ana';
select tests.authenticate_as(:'ana');
select ok(social.follows_user(:'ana', :'bea'), 'follows_delete_own (negativo): otro no puede borrar mi follow');
select lives_ok(format($$select api.unfollow(%L)$$, :'bea'), 'follows_delete_own: dejar de seguir');
select is((select seguidores_count from profiles.profiles where user_id = :'bea'), 0, 'Trigger: seguidores_count -1');

-- bloqueos
select tests.authenticate_as(:'carlos');
select lives_ok(format($$select api.block(%L)$$, :'ana'), 'blocks_insert_own: bloquear');
select tests.authenticate_as(:'ana');
select is_empty($$select 1 from social.blocks$$, 'blocks_select_own (negativo): el bloqueado no ve el bloqueo');
select throws_ok(format($$select api.follow(%L)$$, :'carlos'), '42501', null, 'No se puede seguir a quien te bloquea');
select throws_ok(format($$select api.get_profile(p_user => %L)$$, :'carlos'), 'P0002', null, 'El perfil de quien te bloquea no está disponible');
select tests.authenticate_as(:'carlos');
select is((select count(*)::int from social.blocks), 1, 'blocks_select_own: quien bloquea ve su bloqueo');

select * from finish();
rollback;
