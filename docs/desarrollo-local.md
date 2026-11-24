# Guía de desarrollo local con VS Code

Esta guía levanta en tu ordenador todo ICEX Atlas: base de datos con 640 socios ficticios, login OIDC que simula
la web de ICEX Alumni, Edge Functions, la app en un simulador o emulador y el panel admin. Nada sale de tu máquina:
no hacen falta cuentas de Supabase, Firebase ni Apple.

**Sistema recomendado:** macOS, porque permite probar en el simulador de iOS, que es la opción más sencilla.
En Linux se prueba con el emulador de Android. En Windows, usa WSL2; esa vía no está probada.

## 1. Instalar las herramientas (una vez)

| Herramienta | Para qué | Instalación |
|---|---|---|
| Docker Desktop (u OrbStack en macOS) | Supabase local y el IdP de pruebas | docker.com |
| Supabase CLI | `supabase start`, migraciones, tests | `brew install supabase/tap/supabase` |
| FVM + Flutter 3.47.9 | La versión fijada del proyecto | `brew tap leoafarias/fvm && brew install fvm`, y después `fvm install` dentro del repo |
| Xcode (macOS) | Simulador de iOS | App Store, luego `sudo xcodebuild -runFirstLaunch` |
| Android Studio | Emulador de Android y SDK | developer.android.com/studio |
| Deno 2 (opcional) | Lint y tests de las Edge Functions | `brew install deno` |
| Node 22 (opcional) | Tests de extremo a extremo | `brew install node` |
| VS Code | Editor | code.visualstudio.com |

Comprueba la instalación con `flutter doctor`. Ejecuta `fvm flutter doctor` si no tienes Flutter global.

## 2. Clonar y abrir en VS Code

```bash
git clone git@github.com:sergiopuertas/ICEX-Atlas.git
cd ICEX-Atlas
fvm use 3.47.9          # crea .fvm/flutter_sdk y le dice a VS Code qué Flutter usar
code .
```

VS Code te propondrá instalar las extensiones recomendadas (Flutter, Dart, Deno, Docker, YAML y Mermaid). Acepta.
El repositorio ya trae `.vscode/` con:
- **launch.json**: «App · local», «Panel admin · local (Chrome :3000)» y «Tests Flutter · app».
- **settings.json**: Deno activado solo en `supabase/functions` y formato al guardar.

## 3. Arrancar el backend

Desde la terminal integrada de VS Code (`` Ctrl+` ``), en la raíz del repositorio:

```bash
# Una sola vez: el IdP de pruebas debe resolverse en tu máquina
echo "127.0.0.1 idp.icex-atlas.test" | sudo tee -a /etc/hosts

supabase start          # la primera vez descarga imágenes (unos minutos). Aplica migraciones y datos semilla
./scripts/setup-local.sh
```

`setup-local.sh` hace lo siguiente:
- genera la CA de desarrollo y el certificado del IdP;
- levanta el IdP en Docker;
- registra el proveedor `custom:icex-alumni` en Supabase Auth;
- guarda en Vault los secretos que usan las tareas Cron;
- escribe `app/env/local.json` con la URL y la clave pública locales.

Se puede repetir sin problema.

URLs útiles:
- **Supabase Studio** (tablas, SQL, Auth, Storage): http://127.0.0.1:54323
- **API:** http://127.0.0.1:54321
- **IdP de pruebas:** https://idp.icex-atlas.test:9010/.well-known/openid-configuration

## 4. Preparar el dispositivo

### Opción A: simulador de iOS (macOS)

```bash
open -a Simulator                                              # arranca un iPhone
xcrun simctl keychain booted add-root-cert docker/certs/dev-ca.crt
```

El simulador comparte la red y el `/etc/hosts` de tu Mac, así que no hace falta nada más. La CA hay que instalarla
de nuevo si borras el simulador o creas otro.

### Opción B: emulador de Android

1. En Android Studio → *Device Manager*, crea un dispositivo con imagen **«Google APIs»**. Las imágenes
   «Google Play» no permiten root y no sirven para esto.
2. Arráncalo desde la terminal con el sistema escribible:
   ```bash
   ~/Library/Android/sdk/emulator/emulator -list-avds
   ~/Library/Android/sdk/emulator/emulator -avd <nombre> -writable-system
   ```
   En Linux, la ruta del SDK suele ser `~/Android/Sdk`.
3. Con el emulador encendido:
   ```bash
   ./scripts/android-dev.sh
   ```
   El script redirige los puertos 54321 y 9010 a tu máquina, añade `idp.icex-atlas.test` al hosts del emulador y copia
   la CA. Instala la CA a mano **la primera vez** siguiendo lo que indica el script. Repite el script cada vez que
   reinicies el emulador.

## 5. Ejecutar la app desde VS Code

1. En la barra de estado (abajo a la derecha), elige el dispositivo: el iPhone del simulador o el emulador.
2. Abre la vista *Run and Debug* (`⇧⌘D`), elige **«App · local»** y pulsa **F5**.
   Es equivalente a ejecutar `cd app && flutter run --dart-define-from-file=env/local.json`.
3. **Acceso rápido (recomendado):** en la portada, bajo «Modo desarrollo», toca una cuenta de prueba
   (Ana, Javier, Laura o Pedro). Entra al momento, sin navegador. Si no ves el panel, vuelve a ejecutar
   `./scripts/setup-local.sh` (añade `"DEV_LOGIN": true` a `app/env/local.json`) y, si acabas de actualizar el
   repositorio, reinicia Supabase con `supabase stop && supabase start`, porque `config.toml` activa el acceso
   por contraseña. Detalle y diferencias con producción en `docs/autenticacion.md`.
4. **Flujo real (OIDC):** pulsa «Entrar con mi cuenta ICEX Alumni». Se abre la web simulada: elige un usuario.
   En un emulador recién creado, Chrome enseña antes sus pantallas de bienvenida y de cuenta de Google. Son de
   Chrome, no de la app: pásalas una vez.

| Usuario | Qué ver |
|---|---|
| **Ana Ortega** | Socia con datos: feed, red, mensajes y perfil completo |
| **Javier Martín** | Otro socio. Abre una sesión con él en un segundo dispositivo para ver los mensajes en tiempo real |
| **Laura Gil** | Administradora (también entra en el panel admin) |
| **Nuria Becaria Nueva** | Socia que entra por primera vez: se crea su cuenta al vuelo |
| **Pedro Sin Membresía** | **No socio**: ve la pantalla «acceso solo para socios» y no puede leer nada |

Sobre la velocidad: en **debug** la app va mucho más lenta que la versión real (el código no está compilado), y
en el emulador aún más. Avisos como «Skipped N frames» o «La app no responde» en debug no indican cómo irá en un
móvil. Para juzgar la fluidez, usa un móvil real con `flutter run --profile` o `./scripts/perf-app.sh`.

Durante la depuración:
- **Hot reload:** guarda el fichero, o `r` en la consola de depuración.
- **Hot restart:** `⇧⌘F5`.
- **DevTools:** desde la paleta, con «Flutter: Open DevTools».

Qué funciona en local y qué no:
- El **orientador** responde con un proveedor simulado (respuestas fijas pero coherentes).
- Las **notificaciones push** no llegan al dispositivo (no hay Firebase). El centro de notificaciones dentro de la
  app sí funciona.
- El **mapa** usa teselas de OpenStreetMap: necesita internet.

## 6. Panel de administración

Lanza **«Panel admin · local (Chrome :3000)»** con F5 y entra como **Laura Gil**. El puerto 3000 es fijo porque es el
que Supabase local tiene permitido para volver tras el login. Si lo cambias, el login del panel falla.

## 7. Ver todo el código y los secretos

En VS Code tienes todo el código: `app/`, `admin/`, `supabase/` (migraciones, funciones y tests), `docker/`,
`wordpress/`, `scripts/` y `docs/`. Para orientarte, `docs/arquitectura.md` explica cómo encaja cada pieza.

**No hay secretos reales en ningún sitio todavía.** Los de producción (claves de Supabase, Firebase, Apple, IA…)
se crearán al resolver `docs/PARADAS_HUMANAS.md` y vivirán en gestores de secretos, nunca en Git. Los secretos
**de desarrollo** se generan en tu máquina y git los ignora a propósito:

| Fichero | Qué contiene | Quién lo crea |
|---|---|---|
| `supabase/functions/.env` | Configuración de las Edge Functions (proveedores simulados, token de sincronía de pruebas) | `setup-local.sh` (copia de `.env.local.example`) |
| `app/env/local.json` | URL y clave **pública** de la Supabase local | `setup-local.sh` |
| `docker/certs/*` | CA de desarrollo y certificado TLS del IdP | `setup-local.sh` (`dev-certs.sh`) |
| Claves locales de Supabase | anon/service_role y contraseña de la BD **locales** | `supabase status` las muestra |

Las plantillas que documentan cada variable (`.env.example`, `app/env/example.json` y
`supabase/functions/.env.local.example`) sí están en el repositorio.

## 8. Tests desde VS Code

- **Flutter:** pestaña *Testing* (icono del matraz), o la configuración «Tests Flutter · app».
- **Base de datos:** `supabase test db`.
- **Edge Functions:** `cd supabase/functions && deno test --no-lock --allow-env --allow-net tests/`.
- **De extremo a extremo:**
  ```bash
  source scripts/lib/supabase-env.sh      # desde la raíz: API_URL, ANON_KEY, SERVICE_ROLE_KEY…
  cd scripts/e2e && npm ci
  SUPABASE_ANON_KEY=$ANON_KEY SUPABASE_SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY \
    NODE_EXTRA_CA_CERTS=../../docker/certs/dev-ca.crt node --test --test-concurrency=1 ./*.test.mjs
  ```
- **Diseño en todos los tamaños:** `flutter test test/usability/layout_matrix_test.dart`. Cada pantalla en 4
  tamaños (de 320 pt a tableta) con texto al 100 %, 130 % y 200 %; falla si algo se desborda.
- **Accesibilidad:** `flutter test test/usability/accessibility_test.dart`. Zonas táctiles de 48 dp y 44 pt,
  etiquetas para el lector de pantalla y contraste de texto.
- **Presupuestos de latencia:** `flutter test test/performance`. Cuántas peticiones hace cada flujo (arranque,
  cambio de pestaña, ráfagas de Realtime, búsqueda) y que recomendar no reconstruya otras tarjetas.
- **Rendimiento de la base de datos:** `./scripts/perf.sh` (p95 de feed y directorio < 200 ms).
- **Fluidez en un móvil real:** `./scripts/perf-app.sh` (modo profile; percentil 90 de frame < 16 ms).

## 9. Día a día

| Quiero… | Comando |
|---|---|
| Parar todo (conserva los datos) | `supabase stop && docker compose -f docker/docker-compose.yml stop` |
| Volver a arrancar | `supabase start && ./scripts/setup-local.sh` |
| Datos limpios (vuelve a aplicar migraciones y semilla) | `supabase db reset && ./scripts/setup-local.sh` |
| Crear una migración | `supabase migration new <nombre>`, editar el SQL y después `supabase db reset` |
| Regenerar el código Riverpod/Drift | `cd app && dart run build_runner build --delete-conflicting-outputs` |

## 10. Problemas frecuentes

| Síntoma | Solución |
|---|---|
| El login se queda en blanco o da error de certificado | La CA no está instalada en el simulador o emulador (paso 4) |
| «Failed host lookup: idp.icex-atlas.test» | Falta la línea en `/etc/hosts`. En Android, ejecuta `./scripts/android-dev.sh` |
| Android: «Connection refused 127.0.0.1:54321» | Se perdió `adb reverse` al reiniciar el emulador: ejecuta `./scripts/android-dev.sh` |
| Tras el login vuelve a la pantalla de acceso | ¿Has entrado como Pedro? Es el no socio. Si no, ejecuta `./scripts/setup-local.sh`, que registra el proveedor con la lista de claims permitidos |
| El orientador o la subida de fotos fallan | Mira los logs: `docker logs -f supabase_edge_runtime_icex-atlas` |
| `setup-local.sh`: «No he podido leer la configuración de la Supabase local» | `supabase start` no terminó o la base de datos aún arranca: espera a que `supabase status` responda bien y repite |
| `supabase start` falla por puertos ocupados | Otro proyecto Supabase está encendido: `supabase stop --project-id <otro>` |
| El editor marca errores en `*.g.dart` | Regenera el código (tabla del apartado 9) |
