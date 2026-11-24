-- =============================================================================
-- Cuentas de acceso rápido para DESARROLLO LOCAL (no se aplica nunca en producción:
-- `supabase db push` no ejecuta seeds; solo `supabase db reset` en local y
-- scripts/setup-local.sh).
--
-- Permite entrar desde la app con email + contraseña sin pasar por el navegador ni por
-- el proveedor OIDC (botones «Modo desarrollo» de la portada, con DEV_LOGIN=true).
-- La contraseña es pública a propósito: los datos son ficticios y solo existen en tu
-- Supabase local.
--
-- Seguridad: aunque el proveedor Email esté activo en local, nadie puede darse de alta
-- con email: identity.before_user_created rechaza cualquier alta que no venga de
-- `custom:icex-alumni`. Solo pueden entrar estas cuentas ya existentes.
-- Idempotente: se puede ejecutar las veces que haga falta.
-- =============================================================================

-- Socias y socios (existen en seed.sql): ana (socia), javier (socio), laura (admin).
update auth.users
set encrypted_password = extensions.crypt('atlas-dev-local', extensions.gen_salt('bf'))
where email in (
  'ana.ortega@demo.icexalumni.invalid',
  'javier.martin@demo.icexalumni.invalid',
  'laura.gil@demo.icexalumni.invalid'
);

-- Pedro: cuenta SIN membresía, para probar la pantalla «Acceso solo para socios».
-- No tiene fila en identity.members, así que el hook custom_access_token rechaza su
-- token (403 icex_member_not_active) y la app muestra el acceso denegado.
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, email_confirmed_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  email_change_token_current, phone_change, phone_change_token, reauthentication_token
)
select
  'b0000000-0000-4000-8000-00000000dead', '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'pedro.nosocio@demo.icexalumni.invalid',
  extensions.crypt('atlas-dev-local', extensions.gen_salt('bf')),
  '{"provider": "email", "providers": ["email"]}',
  '{"name": "Pedro Sin Membresía", "sub": "pedro"}',
  now(), now(), now(),
  '', '', '', '', '', '', '', ''
where not exists (
  select 1 from auth.users where email = 'pedro.nosocio@demo.icexalumni.invalid'
);

-- Identidad «email» de cada cuenta de desarrollo (GoTrue la usa en el acceso con contraseña).
insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select u.id::text, u.id,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       'email', now(), now(), now()
from auth.users u
where u.email in (
  'ana.ortega@demo.icexalumni.invalid',
  'javier.martin@demo.icexalumni.invalid',
  'laura.gil@demo.icexalumni.invalid',
  'pedro.nosocio@demo.icexalumni.invalid'
)
and not exists (
  select 1 from auth.identities i where i.user_id = u.id and i.provider = 'email'
);
