# WordPress de ICEX Alumni como proveedor OpenID Connect

ICEX Atlas no tiene usuarios propios: los socios entran con su cuenta de la web de ICEX Alumni.
WordPress actúa como proveedor OIDC (plugin **OpenID Connect Server**, de Automattic) y Supabase Auth lo usa
como proveedor personalizado `custom:icex-alumni`.

> ⚠ Todo esto se hace **primero en una copia de pruebas** de la web (staging). Ver `docs/PARADAS_HUMANAS.md`.

## 1. Plugin OpenID Connect Server

1. Instalar y activar **OpenID Connect Server** (wordpress.org/plugins/openid-connect-server). Requiere HTTPS.
2. Generar la clave RSA del plugin y añadir a `wp-config.php` (fuera del webroot):
   ```php
   define( 'OIDC_PUBLIC_KEY', file_get_contents( '/ruta/segura/oidc-public.pem' ) );
   define( 'OIDC_PRIVATE_KEY', file_get_contents( '/ruta/segura/oidc-private.pem' ) );
   ```
   ```bash
   openssl genrsa -out oidc-private.pem 4096 && openssl rsa -in oidc-private.pem -pubout -out oidc-public.pem
   ```
3. Registrar el cliente de Supabase en `wp-config.php` (o con el filtro `oidc_registered_clients`):
   ```php
   define( 'OIDC_CLIENTS', array(
     'icex-atlas' => array(
       'name'         => 'ICEX Atlas',
       'secret'       => '<SECRETO LARGO ALEATORIO — se copia también en Supabase>',
       'redirect_uri' => 'https://<project-ref>.supabase.co/auth/v1/callback',
       'grant_types'  => array( 'authorization_code' ),
       'scope'        => 'openid profile email',
     ),
   ) );
   ```
4. Comprobar el descubrimiento: `https://<web>/.well-known/openid-configuration` debe responder JSON con el `issuer`.

## 2. Claims de membresía y endpoint de sincronía

1. Copiar `oidc-claims.php` a `wp-content/mu-plugins/icex-atlas-oidc.php`.
2. **Adaptar** `icex_atlas_is_active_member()` a cómo marca la web a sus socios al corriente (rol, plugin de
   membresías o metadato). Opcional: metadatos `icex_promocion` y `icex_fase` para rellenar el perfil inicial.
3. Añadir a `wp-config.php` el token de sincronía (≥ 32 caracteres; el mismo va en el secreto `WP_SYNC_TOKEN`
   de las Edge Functions):
   ```php
   define( 'ICEX_ATLAS_SYNC_TOKEN', '<token largo aleatorio>' );
   ```

### Contrato del endpoint de sincronía

```
POST https://<web>/wp-json/icex-alumni/v1/memberships
Authorization: Bearer <ICEX_ATLAS_SYNC_TOKEN>
Content-Type: application/json

{ "subjects": ["login1", "login2"] }          // máximo 1000 por llamada

200 → { "memberships": { "login1": "active", "login2": "inactive" } }
```

- `active`: sigue siendo socio · `inactive`: se ha dado de baja → ICEX Atlas revoca acceso y sesiones.
- `unknown`: el usuario no existe; **no** revoca (evita bajas masivas por errores).
- La Edge Function `membership-sync` (diaria, 03:15 en Madrid) aborta si más del 5 % saldría revocado
  (`MEMBERSHIP_MAX_REVOKE_RATIO`) y lo registra para revisión manual.

## 3. Pruebas

```bash
# Claims: tras iniciar sesión en la app de pruebas, el ID token debe incluir icex_member_verified
curl -s https://<web>/.well-known/openid-configuration | jq .issuer

# Sincronía
curl -s -X POST https://<web>/wp-json/icex-alumni/v1/memberships \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"subjects":["usuario-de-prueba"]}'
```

En local el proveedor de pruebas (`docker/oidc-provider`) imita exactamente este contrato.
