# Autenticación: desarrollo y producción

La app solo deja entrar a socios verificados de ICEX Alumni. El código está preparado para dos modos:
el **acceso real** (OIDC contra la web de la asociación), que es el único que existe en producción, y un
**acceso rápido de desarrollo** con cuentas de prueba, que solo existe en local.

## Piezas

| Pieza | Dónde | Qué hace |
| --- | --- | --- |
| `AuthGateway` | `app/lib/core/auth/auth_gateway.dart` | Interfaz única de acceso. La app no habla con Supabase Auth directamente. |
| `SupabaseAuthGateway.signIn` | ídem | Acceso real: `signInWithOAuth('custom:icex-alumni')` con PKCE en el navegador. |
| `SupabaseAuthGateway.signInWithPassword` | ídem | Acceso de desarrollo con email y contraseña. |
| `SessionController` | `app/lib/core/auth/session_controller.dart` | Estados `SigningIn`, `SignedIn`, `SignedOut` y `AccessDenied`. Las dos vías terminan igual. |
| `identity.before_user_created` | migración `…_identity.sql` | Rechaza cualquier **alta** que no venga del proveedor OIDC con el claim de socio. |
| `identity.custom_access_token` | ídem | Rechaza el **token** de quien no tenga membresía activa en `identity.members`. |
| `AppEnv.devLogin` | `app/lib/core/config/app_env.dart` | `DEV_LOGIN=true` muestra el panel «Modo desarrollo». Se ignora si `APP_ENV=production`. |

## Desarrollo local

`./scripts/setup-local.sh` deja todo listo:

1. Registra el proveedor OIDC de pruebas (`docker/oidc-provider`, usuarios ana, javier, laura, nueva y pedro).
2. Aplica `supabase/seed_dev_accounts.sql`, que da contraseña (`atlas-dev-local`) a ana, javier y laura y crea a
   pedro sin membresía.
3. Escribe `app/env/local.json` con `"DEV_LOGIN": true`.

En la portada aparece «Modo desarrollo» con las cuentas de prueba: un toque y entras, **sin navegador**.
El botón principal sigue usando el flujo OIDC real, para probarlo cuando haga falta.

- El proveedor Email está activo **solo en `supabase/config.toml`** (local). No permite altas nuevas: el hook
  `before_user_created` rechaza todo lo que no venga de `custom:icex-alumni`.
- Al cambiar `[auth.email]` en `config.toml` hay que reiniciar: `supabase stop && supabase start`.
- Las cuentas de desarrollo se pueden volver a aplicar sin borrar datos:
  `psql "$DB_URL" -f supabase/seed_dev_accounts.sql` (o se aplican solas con `supabase db reset`).
- **Sobre lo que se ve en el emulador:** con el flujo OIDC, Android abre Chrome. En un emulador recién creado,
  Chrome enseña primero sus pantallas de bienvenida y de cuenta de Google. Eso es de Chrome, no de la app: en un
  móvil real o tras pasar esas pantallas una vez, se abre directamente el formulario de la web de ICEX Alumni.

## Producción

Solo existe el acceso OIDC contra WordPress. Pasos (detalle en `PARADAS_HUMANAS.md`, bloque C, y `runbook.md` §1):

1. Instalar el plugin **OpenID Connect Server** y `wordpress/oidc-claims.php` en WordPress (primero en staging).
2. Registrar el proveedor en Supabase (`custom:icex-alumni`) con el issuer de WordPress, el `client_id` y el
   `client_secret`, y el *allowlist* de claims `icex_member_verified`, `icex_promocion` e `icex_fase`.
3. Activar los hooks `before_user_created` y `custom_access_token` (Dashboard → Authentication → Hooks).
4. **Dejar desactivado el proveedor Email** (Dashboard → Authentication → Providers → Email). Si alguna vez se usa
   `supabase config push` contra producción, revisa antes `[auth.email] enabled` en `config.toml`, porque en local
   vale `true`.
5. Compilar con `env/production.json`, que lleva `"APP_ENV": "production"` y **no** lleva `DEV_LOGIN`. Aunque lo
   llevara, `AppEnv.devLogin` lo ignora en producción, y el test `app_env_test.dart` lo comprueba.
6. Probar en staging con un socio y un no socio (C3). Comprobar también que WordPress respeta `prompt=login`
   («Entrar con otra cuenta», D-024). Si no lo hace, para cambiar de cuenta hay que cerrar sesión en la web.

### Cambiar de proveedor de identidad

La app solo depende de `AuthGateway`. Para usar otro proveedor OIDC (Auth0, Keycloak, Entra ID…) basta con
registrarlo en Supabase con otro identificador, poner ese identificador en `OIDC_PROVIDER`, y ajustar el claim
de socio en `identity.claim_verified` y en el hook. La app no necesita más cambios.
