-- =============================================================================
-- ICEX Atlas · 20261125-0100 · Beta abierta: alta con email y contraseña
-- Para la beta pública cualquiera puede crear una cuenta con correo y contraseña, sin ser
-- socio de ICEX Alumni. El acceso de socios por el IdP de WordPress sigue igual y volverá
-- a ser el único cuando termine la beta.
--
--   config.app_config 'access.mode':
--     "alumni"     (por defecto) solo socios verificados por el IdP (OIDC).
--     "open_beta"  además, cualquiera con email y contraseña (cuenta de origen «beta»).
--
-- Volver a «alumni» cierra el registro nuevo; las cuentas beta existentes siguen entrando
-- hasta que se decida qué hacer con ellas (identity.members.origen = 'beta').
-- =============================================================================

create type identity.member_origin as enum ('alumni', 'beta');
alter table identity.members add column origen identity.member_origin not null default 'alumni';
comment on column identity.members.origen is
  'alumni: verificado por el IdP de ICEX Alumni. beta: cuenta con email y contraseña de la beta abierta.';

create or replace function identity.access_mode()
returns text language sql stable security definer set search_path = ''
as $$ select coalesce(config.get('access.mode') #>> '{}', 'alumni'); $$;
grant execute on function identity.access_mode() to supabase_auth_admin, authenticated, service_role;

-- Hook Before User Created: socios del IdP (como antes) o, en beta abierta, email.
create or replace function identity.before_user_created(event jsonb)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_meta jsonb := coalesce(event -> 'user' -> 'user_metadata', '{}'::jsonb);
  v_provider text := coalesce(event -> 'user' -> 'app_metadata' ->> 'provider', '');
begin
  if v_provider = 'custom:icex-alumni' and identity.claim_verified(v_meta) then
    return '{}'::jsonb;
  end if;
  if v_provider = 'email' and identity.access_mode() = 'open_beta' then
    return '{}'::jsonb;
  end if;
  return jsonb_build_object('error', jsonb_build_object(
    'http_code', 403,
    'message', case when v_provider = 'email' then 'signup_closed' else 'icex_member_not_verified' end));
end;
$$;

-- Alta en members: socio verificado (alumni) o cuenta de email en beta abierta (beta).
create or replace function identity.on_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if identity.claim_verified(new.raw_user_meta_data) then
    insert into identity.members (user_id, wp_subject, status, origen)
    values (new.id, coalesce(new.raw_user_meta_data ->> 'sub', new.raw_user_meta_data -> 'custom_claims' ->> 'sub'),
            'active', 'alumni')
    on conflict (user_id) do nothing;
  elsif coalesce(new.raw_app_meta_data ->> 'provider', '') = 'email' and identity.access_mode() = 'open_beta' then
    insert into identity.members (user_id, status, origen)
    values (new.id, 'active', 'beta')
    on conflict (user_id) do nothing;
  end if;
  return new;
end;
$$;

-- Token: indica el origen (la app lo usa para, p. ej., dejar declarar la promoción).
create or replace function identity.custom_access_token(event jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_uid uuid := (event ->> 'user_id')::uuid;
  v_claims jsonb := coalesce(event -> 'claims', '{}'::jsonb);
  v_role identity.member_role;
  v_origen identity.member_origin;
begin
  select m.role, m.origen into v_role, v_origen
  from identity.members m
  where m.user_id = v_uid and m.status = 'active';

  if v_role is null then
    return jsonb_build_object('error', jsonb_build_object(
      'http_code', 403, 'message', 'icex_member_not_active'));
  end if;

  v_claims := jsonb_set(v_claims, '{user_role}', to_jsonb(v_role::text));
  v_claims := jsonb_set(v_claims, '{icex_member}', 'true'::jsonb);
  v_claims := jsonb_set(v_claims, '{icex_origen}', to_jsonb(v_origen::text));
  return jsonb_build_object('claims', v_claims);
end;
$$;

-- ------------------------------------------------------------------ perfil ---
-- Promoción 0 = «sin promoción» (cuentas beta que no son alumni o no la han indicado).
alter table profiles.profiles drop constraint if exists profiles_promocion_check;
alter table profiles.profiles add constraint profiles_promocion_check check (promocion between 0 and 99);

create or replace function profiles.on_member_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta jsonb;
  v_name text;
  v_promo int;
  v_fase profiles.fase;
begin
  select coalesce(u.raw_user_meta_data, '{}'::jsonb) into v_meta from auth.users u where u.id = new.user_id;
  v_name := left(trim(coalesce(nullif(v_meta ->> 'name', ''), nullif(v_meta -> 'custom_claims' ->> 'name', ''),
                               'Socio ICEX Alumni')), 120);
  if char_length(v_name) < 2 then v_name := 'Socio ICEX Alumni'; end if;

  if new.origen = 'beta' then
    -- Lo que la persona declaró al registrarse (opcional) y validado aquí.
    v_promo := case when (v_meta ->> 'promocion') ~ '^\d{1,2}$'
                     and (v_meta ->> 'promocion')::int between 1 and profiles.current_promocion()
                    then (v_meta ->> 'promocion')::int else 0 end;
    v_fase := case when v_promo > 0 and v_promo >= profiles.current_promocion() then 'fase_0'::profiles.fase
                   else 'activo'::profiles.fase end;
  else
    v_promo := least(greatest(coalesce((v_meta -> 'custom_claims' ->> 'icex_promocion')::int,
                                       (v_meta ->> 'icex_promocion')::int, 1), 1), 99);
    v_fase := coalesce((v_meta -> 'custom_claims' ->> 'icex_fase')::profiles.fase,
                       case when v_promo >= profiles.current_promocion() then 'fase_0'::profiles.fase
                            else 'activo'::profiles.fase end);
  end if;

  insert into profiles.profiles (user_id, slug, nombre, promocion, fase)
  values (new.user_id, profiles.slugify(v_name, new.user_id), v_name, v_promo, v_fase)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

-- Las cuentas beta declaran su promoción (los socios la traen del IdP y no la cambian).
create or replace function api.set_my_promocion(p_promocion int)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := identity.require_member();
begin
  if (select origen from identity.members where user_id = v_uid) <> 'beta' then
    raise exception 'La promoción de los socios viene de ICEX Alumni' using errcode = '42501';
  end if;
  if p_promocion is null or p_promocion < 0 or p_promocion > profiles.current_promocion() then
    raise exception 'Promoción no válida' using errcode = '22023';
  end if;
  update profiles.profiles set promocion = p_promocion where user_id = v_uid;
  return api.get_profile(p_user => v_uid);
end;
$$;
revoke execute on function api.set_my_promocion(int) from public, anon;
grant execute on function api.set_my_promocion(int) to authenticated;

-- me(): origen de la cuenta y modo de acceso (la app adapta textos y opciones).
create or replace function api.me()
returns jsonb language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_role text;
  v_origen text;
  v_profile jsonb;
begin
  select m.role::text, m.origen::text into v_role, v_origen from identity.members m where m.user_id = v_uid;
  select profiles.card(p, v_uid, false) || jsonb_build_object(
           'bio', p.bio, 'pais_code', p.pais_code, 'visibilidad', p.visibilidad,
           'acepta_sugerencias', p.acepta_sugerencias, 'posts_count', p.posts_count,
           'lat', extensions.st_y(p.ubicacion::extensions.geometry), 'lng', extensions.st_x(p.ubicacion::extensions.geometry))
    into v_profile
    from profiles.profiles p where p.user_id = v_uid;
  return jsonb_build_object('user_id', v_uid, 'role', v_role, 'origen', v_origen,
                            'access_mode', identity.access_mode(), 'profile', v_profile);
end;
$$;
