-- Helpers de test (incluidos con \ir desde cada fichero; viven en la transacción del test).
create schema if not exists tests;

-- Socio verificado: se crea como lo haría Auth tras el hook (claim icex_member_verified).
create or replace function tests.create_member(p_name text, p_role identity.member_role default 'socio',
  p_promo int default 49)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid := gen_random_uuid();
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'test-' || v_id || '@test.invalid', '{"provider":"custom:icex-alumni"}',
          jsonb_build_object('name', p_name, 'sub', 'test-' || v_id,
            'custom_claims', jsonb_build_object('icex_member_verified', true, 'icex_promocion', p_promo)),
          now(), now());
  if p_role <> 'socio' then update identity.members set role = p_role where user_id = v_id; end if;
  return v_id;
end $$;

-- Usuario de Auth SIN membresía (p. ej. creado antes de una baja o por error).
create or replace function tests.create_unverified(p_name text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid := gen_random_uuid();
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'nv-' || v_id || '@test.invalid', '{"provider":"custom:icex-alumni"}',
          jsonb_build_object('name', p_name, 'custom_claims', jsonb_build_object('icex_member_verified', false)),
          now(), now());
  return v_id;
end $$;

create or replace function tests.authenticate_as(p_user uuid)
returns void language plpgsql as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aud', 'authenticated')::text, true);
end $$;

create or replace function tests.as_anon()
returns void language plpgsql as $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
end $$;

create or replace function tests.clear_authentication()
returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', null, true);
end $$;

grant usage on schema tests to authenticated, anon;
grant execute on all functions in schema tests to authenticated, anon;

-- Longitud de una cola pgmq (los tests a veces corren como `authenticated`).
create or replace function tests.queue_len(p_queue text)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v bigint;
begin
  execute format('select count(*) from pgmq.%I', 'q_' || p_queue) into v;
  return v;
end $$;
grant execute on function tests.queue_len(text) to authenticated;
