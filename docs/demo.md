# Grabar la demo de ICEX Atlas

Demo de 2–3 minutos con **datos ficticios**: unas 40 personas inventadas con perfiles,
trayectoria, mapa, clubs, publicaciones, comentarios, novedades y conversaciones. Todo vive
en el proyecto de **pruebas** (`icex-atlas-carga`), nunca en el de la beta: así los
probadores no ven gente inventada y la demo no ve datos reales.

## 1. Preparar (10 minutos, una vez)

1. En GitHub → *Settings → Environments → carga*, añade el secreto `DEMO_PASSWORD`: una
   contraseña para las cuentas de la demo (no se imprime en los logs).
2. Si el proyecto de pruebas no tiene aún el esquema: *Actions → Deploy backend → carga*.
3. *Actions → Demo → Run workflow → crear*. Crea la comunidad y compila la APK de la demo,
   que queda como artefacto de la ejecución (`icex-atlas-demo-N.apk`).
   - Con **aviso** marcado, la app muestra arriba «Comunidad de demostración · perfiles
     ficticios». Recomendado si el vídeo se va a enseñar fuera del equipo.
   - **crear** rehace la comunidad desde cero: los posts vuelven a ser «de hace unos días».
     Lánzalo el mismo día de grabar.
4. Instala la APK en **dos móviles Android**. Si tienen instalada la beta, desinstálala
   antes: es la misma app con otra firma.

Cuentas (contraseña: la de `DEMO_PASSWORD`):

| Cuenta | Para qué |
|---|---|
| `nueva@demo.icexatlas.invalid` | Lucía, recién registrada: perfil vacío, no sigue a nadie |
| `marina@demo.icexatlas.invalid` | Marina, perfil completo, con mensajes; un mensaje sin leer de Javier |
| `javier@demo.icexatlas.invalid` | Javier (51ª, Fase 0), el segundo móvil para el chat en directo |

Al terminar: *Actions → Demo → borrar*.

## 2. Guion (≈ 2:30)

| Tiempo | Móvil | Qué se ve | Qué contar |
|---|---|---|---|
| 0:00 | A | Portada → *Crear cuenta*: nombre, correo, contraseña y promoción opcional (no se envía) | «Cualquier alumni se da de alta en un minuto» |
| 0:15 | A | Entrar como **Lucía**. Inicio: aviso «Tu perfil está al 0 %», bienvenida, *Personas que quizá conozcas* y *Destacado en la comunidad* | «El primer día no está vacío: la app te propone gente y lo que se mueve» |
| 0:35 | A | Seguir a 2 personas del carrusel. Tocar un chip del aviso → edición del perfil | «Cuanto más completo, mejor te encuentran» |
| 0:50 | A | Cerrar sesión y entrar como **Marina**. Novedad fijada del Encuentro Anual, feed con ofertas, eventos y logros. Recomendar y comentar uno | La red de verdad: publicaciones de la comunidad |
| 1:15 | A | **Red**: buscar «Shanghái» o filtrar por promoción. Abrir un perfil: trayectoria, seguidores | Directorio de alumni por todo el mundo |
| 1:30 | A | **Mapa**: zoom del mundo a Ciudad de México; clubs | «¿Quién hay en mi ciudad o en mi próximo destino?» |
| 1:45 | A + B | **Mensajes** (badge con 1). Abrir la conversación con Javier. En el móvil B (Javier), escribir: aparece al instante en A | Mentoría entre promociones, en tiempo real |
| 2:10 | A | **Orientador**: elegir una pregunta guiada | Orientación sobre la carrera internacional |
| 2:25 | A | Perfil de Marina → *Ajustes* → privacidad de cada dato | Privacidad y control de los datos |

Consejo: ensáyalo una vez con el cronómetro. Si sobra tiempo, el mapa y el chat son lo que
más luce.

## 3. Grabar la pantalla

- **Con el móvil conectado al ordenador (la mejor calidad):** [scrcpy](https://github.com/Genymobile/scrcpy)
  (gratis, Windows/macOS/Linux). Activa la *depuración USB* en el móvil
  (*Ajustes → Información → pulsar 7 veces «Número de compilación»*, y luego *Opciones de
  desarrollador → Depuración USB*), conéctalo y ejecuta:
  ```bash
  scrcpy --record demo.mp4 --max-fps 60 --no-audio --show-touches
  ```
  `--show-touches` marca cada toque con un círculo, lo que ayuda a seguir el vídeo. Para el
  chat en directo, abre dos ventanas de scrcpy (una por móvil, con `--serial`) y graba la
  pantalla del ordenador con OBS.
- **Solo con el móvil:** la grabadora de pantalla de Android (en los ajustes rápidos). Activa
  *Mostrar toques* en las opciones de desarrollador.
- Antes de grabar: modo *No molestar*, batería y hora visibles con buen aspecto, tamaño de
  texto normal y brillo alto.

## 4. Sin GitHub (en local)

Con la app arrancada (`AUTH_MODE=password ./scripts/start-local.sh`), en otra terminal:

```bash
./scripts/demo-local.sh              # cambia los datos de desarrollo por los de la demo
./scripts/demo-local.sh --restaurar  # vuelve a los datos de desarrollo
```

Prepara Python si hace falta: si a tu `python3` le falta psycopg, crea un entorno en `~/.venvs/icex`. Las
cuentas son las de arriba, con la contraseña `demo1234`, o la que pongas en `DEMO_PASSWORD`.
