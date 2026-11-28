-- Beta abierta: alta con email y contraseña sin ser socio (config 'access.mode').
begin;
\ir helpers.inc
select plan(17);

create function pg_temp.email_user(p_email text, p_meta jsonb default '{}') returns uuid language sql as $$
  insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', p_email,
          '{"provider":"email","providers":["email"]}', p_meta, now(), now())
  returning id;
$$;
create function pg_temp.signup_event(p_provider text) returns jsonb language sql as $$
  select jsonb_build_object('user', jsonb_build_object('app_metadata', jsonb_build_object('provider', p_provider),
                                                       'user_metadata', '{}'::jsonb));
$$;

-- ----------------------------------------------------------- modo «alumni» ---
delete from config.app_config where key = 'access.mode';
select is(identity.access_mode(), 'alumni', 'sin configurar: solo socios');
select is(identity.before_user_created(pg_temp.signup_event('email')) -> 'error' ->> 'message', 'signup_closed',
  'modo alumni: el registro con email está cerrado');
select pg_temp.email_user('cerrado@beta.invalid') as cerrado \gset
select is((select count(*)::int from identity.members where user_id = :'cerrado'), 0,
  'modo alumni: un usuario de email (p. ej. creado a mano) no es socio');

-- ------------------------------------------------------------ beta abierta ---
insert into config.app_config (key, value) values ('access.mode', '"open_beta"');
select is(identity.access_mode(), 'open_beta', 'beta abierta activada por configuración');
select is(identity.before_user_created(pg_temp.signup_event('email')), '{}'::jsonb, 'beta: el registro con email se permite');
select is(identity.before_user_created(pg_temp.signup_event('custom:icex-alumni')) -> 'error' ->> 'message',
  'icex_member_not_verified', 'beta: el IdP sigue exigiendo socio verificado');

select pg_temp.email_user('laura@beta.invalid', '{"name": "Laura Beta", "promocion": "48"}') as laura \gset
select pg_temp.email_user('nadie@beta.invalid', '{"name": "Sin Promo", "promocion": "999"}') as nadie \gset
select is((select origen::text || '/' || status::text from identity.members where user_id = :'laura'), 'beta/active',
  'beta: cuenta de email = socio activo de origen beta');
select is((select promocion from profiles.profiles where user_id = :'laura'), 48::smallint, 'beta: promoción declarada');
select is((select nombre from profiles.profiles where user_id = :'laura'), 'Laura Beta', 'beta: nombre del registro');
select is((select promocion from profiles.profiles where user_id = :'nadie'), 0::smallint,
  'beta: una promoción inválida se guarda como «sin promoción»');

select is(identity.custom_access_token(jsonb_build_object('user_id', :'laura', 'claims', '{}'::jsonb)) -> 'claims' ->> 'icex_origen',
  'beta', 'el token indica el origen');

select tests.authenticate_as(:'laura');
select is(api.me() ->> 'origen', 'beta', 'me(): origen beta');
select is(api.me() ->> 'access_mode', 'open_beta', 'me(): modo de acceso');
select is((api.set_my_promocion(51) ->> 'promocion')::int, 51, 'una cuenta beta puede declarar su promoción');
select throws_ok($$select api.set_my_promocion(200)$$, '22023', null, 'promoción fuera de rango');
select lives_ok($$select api.get_feed()$$, 'una cuenta beta usa la app como cualquier socio');

select tests.create_member('Socia Alumni') as socia \gset
select tests.authenticate_as(:'socia');
select throws_ok($$select api.set_my_promocion(10)$$, '42501', null, 'los socios no cambian su promoción (viene del IdP)');

select * from finish();
rollback;
