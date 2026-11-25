# Pruebas de concurrencia y escalabilidad del backend

Complementan a los tests pgTAP (`supabase/tests`). pgTAP comprueba reglas dentro de **una** transacción, mientras
que estas pruebas abren **decenas de conexiones reales a la vez**, como harían cientos de móviles llamando a
PostgREST. Cada conexión se identifica igual que PostgREST: `role authenticated` y `request.jwt.claims` con el
`sub` del socio. Por eso se ejecutan de verdad la RLS, los triggers y los bloqueos.

```bash
supabase start                                   # con las migraciones aplicadas
pip install "psycopg[binary]"                    # una vez
python3 supabase/stress/concurrency.py           # todos los escenarios (~1 min)
python3 supabase/stress/concurrency.py mixed_chaos event_capacity_race   # solo algunos
CHAOS_SECONDS=150 python3 supabase/stress/concurrency.py mixed_chaos      # prueba de resistencia
python3 supabase/stress/scale.py                 # 30.000 socios (~3 min); SCALE=0.2 para una rápida
```

Cada prueba crea sus propios socios con una etiqueta y los borra al terminar. No toca los datos semilla.

## Escenarios de concurrencia (`concurrency.py`)

| Escenario | Qué se lanza a la vez | Qué tiene que cumplirse |
|---|---|---|
| `send_message_idempotent_under_retries` | 24 reintentos del mismo mensaje, también en el primer contacto | 1 mensaje, 1 conversación, una sola respuesta «nuevo» |
| `crossed_first_contact` | 40 parejas que se escriben por primera vez a la vez | 1 conversación por pareja, con los 2 mensajes |
| `chat_storm_unread_consistency` | 400 mensajes cruzados y marcas de leído | último mensaje correcto, no leídos nunca por debajo de lo real, 0 al leer |
| `out_of_order_message_ids` | mensaje escrito sin cobertura que llega tarde | ni el último mensaje ni el puntero de leído retroceden |
| `message_id_validation` | ids aleatorios, futuros o máximos | rechazados (rompían el orden y los no leídos) |
| `notification_grouping_race` | 25 recomendaciones simultáneas × 20 posts | una notificación agrupada por post, total exacto |
| `block_versus_send` | bloqueo mientras el otro escribe en ráfaga | nada entra después del bloqueo |
| `recommend_storm`, `follow_storm`, `comment_storm`, `club_membership_storm` | altas y bajas mezcladas | contadores exactos |
| `event_capacity_race` | 60 inscripciones a 10 plazas; bajas y altas cruzadas; vaciado | sin overbooking; nadie espera habiendo plazas |
| `orientador_daily_limit_race` | 30 consultas simultáneas por socio | exactamente el límite diario |
| `queue_exactly_once` | 8 consumidores de la misma cola | cada mensaje se procesa una vez |
| `feed_pagination_under_writes` | paginar el feed mientras otros publican | sin duplicados ni huecos |
| `content_deleted_during_interaction` | borrar posts y clubs mientras otros interactúan | solo errores controlados («no encontrado») |
| `partition_maintenance_in_parallel` | el cron de particiones lanzado 8 veces mientras se escribe | sin interbloqueos ni particiones duplicadas |
| `account_deletion_during_activity` | borrar la cuenta mientras otros le escriben, siguen y recomiendan | sin interbloqueos ni datos huérfanos |
| `mixed_chaos` | 32 conexiones haciendo de todo durante 20 s | 0 errores inesperados y todos los invariantes globales |

## Escalabilidad (`scale.py`)

Genera, en SQL y en unos segundos, una comunidad etiquetada: 30.000 socios con ubicación, 1,2 M de seguimientos,
180.000 posts, 900.000 recomendaciones, 900.000 mensajes y 450.000 notificaciones. Después:

1. mide p50/p95 de 17 endpoints en serie, con 60 socios distintos (presupuesto: p95 < 200 ms);
2. los mide con 24 conexiones en paralelo durante 20 s (presupuesto: p95 < 600 ms, sin errores);
3. revisa con `auto_explain` que ninguna ruta caliente recorra entera una tabla grande;
4. lo borra todo (`KEEP=1` para conservarlo y repetir mediciones).

Los resultados y los arreglos que salieron de estas pruebas están en `docs/decisiones.md` (D-029 a D-033).
