// push-dispatcher · invocada por pg_cron cada minuto (service_role).
// 1) message_events → push "mensaje" a destinatarios sin conexión (heartbeat > 90 s) que lo desean.
// 2) push → notificaciones ya filtradas por preferencias; las novedades se expanden por socio.
// Elimina tokens inválidos y confirma (ack) los mensajes procesados.
// Vacía la cola por lotes dentro de un presupuesto de tiempo, con envíos en paralelo acotados;
// un mensaje que falla siempre se descarta tras `maxReads` lecturas (no bloquea la cola).
import { handle, HttpError, json, log } from '../_shared/http.ts';
import { type Db, isServiceCall, serviceClient } from '../_shared/supabase.ts';
import { type PushSender, pushFromEnv, renderPush } from '../_shared/push.ts';

type QueueMsg = { msg_id: number; read_ct: number; message: Record<string, unknown> };
type Target = { user_id: string; online: boolean; wants: boolean; tokens: string[] };

async function rpc<T>(db: Db, fn: string, args: Record<string, unknown>): Promise<T> {
  const { data, error } = await db.rpc(fn, args);
  if (error) throw new Error(`${fn}: ${error.code}`);
  return data as T;
}

export interface DispatchOptions {
  /** Mensajes por lectura de cola. */
  batch?: number;
  /** Envíos simultáneos a FCM (antes: de uno en uno). */
  concurrency?: number;
  /** Tiempo máximo de trabajo por invocación. El cron llama cada minuto: con 45 s nunca se
   *  solapan dos ejecuciones sobre los mismos mensajes (visibilidad en cola: 120 s). */
  budgetMs?: number;
  /** Lecturas tras las que un mensaje que siempre falla se descarta (y se registra). */
  maxReads?: number;
  now?: () => number;
}

/** Ejecuta `fn` sobre `items` con como mucho `limit` tareas a la vez, en orden de inicio. */
export async function pool<T>(items: T[], limit: number, fn: (item: T) => Promise<void>): Promise<void> {
  let next = 0;
  const workers = Array.from({ length: Math.max(1, Math.min(limit, items.length)) }, async () => {
    while (next < items.length) {
      const item = items[next++];
      await fn(item);
    }
  });
  await Promise.all(workers);
}

export async function dispatch(db: Db, sender: PushSender, opts: DispatchOptions = {}) {
  const { batch = 200, concurrency = 16, budgetMs = 45_000, maxReads = 5, now = Date.now } = opts;
  const deadline = now() + budgetMs;
  const stats = {
    mensajes: 0, notificaciones: 0, enviados: 0, fallidos: 0, tokens_invalidos: 0, omitidos_online: 0,
    descartados: 0, lotes: 0,
  };
  const invalid = new Set<string>();

  const deliver = async (target: Target, title: string, body: string, data: Record<string, string>, collapseKey?: string) => {
    for (const token of target.tokens) {
      try {
        const r = await sender.send({ token, title, body, data, collapseKey });
        if (r.ok) stats.enviados++;
        else if (r.invalidToken) invalid.add(token);
        else stats.fallidos++;
      } catch {
        stats.fallidos++;            // un token que falla no tumba el lote ni provoca reenvíos al resto
      }
    }
  };

  /** Procesa un lote: confirma lo procesado y lo irrecuperable; deja en cola lo que falló para reintentar. */
  const runBatch = async (queue: string, msgs: QueueMsg[], each: (m: QueueMsg) => Promise<void>) => {
    const done: number[] = [];
    await pool(msgs, concurrency, async (m) => {
      try {
        await each(m);
        done.push(m.msg_id);
      } catch (e) {
        if (m.read_ct >= maxReads) {
          stats.descartados++;
          done.push(m.msg_id);
          log('push_dispatch_drop', { queue, msg_id: m.msg_id, error: String((e as Error).message ?? e) });
        }
      }
    });
    if (done.length) await rpc(db, 'svc_queue_ack', { p_queue: queue, p_ids: done });
  };

  // ---------------------------------------------------------- mensajes -------
  while (now() < deadline) {
    const events = await rpc<QueueMsg[]>(db, 'svc_queue_read', { p_queue: 'message_events', p_qty: batch, p_vt: 120 });
    if (!events.length) break;
    stats.lotes++;
    const recipients = [...new Set(events.flatMap((e) => (e.message.destinatarios as string[]) ?? []))];
    const senders = [...new Set(events.map((e) => String(e.message.remitente_id)))];
    const [targets, names] = await Promise.all([
      rpc<Target[]>(db, 'svc_push_targets', { p_users: recipients, p_tipo: 'mensaje' }),
      rpc<Record<string, string>>(db, 'svc_display_names', { p_users: senders }),
    ]);
    const byId = new Map(targets.map((t) => [t.user_id, t]));
    await runBatch('message_events', events, async (e) => {
      for (const uid of (e.message.destinatarios as string[]) ?? []) {
        const t = byId.get(uid);
        if (!t || !t.wants) continue;
        if (t.online) { stats.omitidos_online++; continue; }      // ya lo recibe por Realtime
        const { title, body } = renderPush('mensaje', names[String(e.message.remitente_id)] ?? null, 1, {});
        await deliver(t, title, body,
          { tipo: 'mensaje', conversation_id: String(e.message.conversation_id), route: `/mensajes/${e.message.conversation_id}` },
          `conv-${e.message.conversation_id}`);
      }
      stats.mensajes++;
    });
    if (events.length < batch) break;
  }

  // ------------------------------------------------------ notificaciones ------
  while (now() < deadline) {
    const pushes = await rpc<QueueMsg[]>(db, 'svc_queue_read', { p_queue: 'push', p_qty: batch, p_vt: 120 });
    if (!pushes.length) break;
    stats.lotes++;
    const personal = pushes.filter((p) => !p.message.broadcast);
    const users = [...new Set(personal.map((p) => String(p.message.user_id)))];
    const actors = [...new Set(personal.map((p) => p.message.actor_id).filter(Boolean).map(String))];
    const byTipo = new Map<string, Map<string, Target>>();
    for (const tipo of [...new Set(personal.map((p) => String(p.message.tipo)))]) {
      const ts = await rpc<Target[]>(db, 'svc_push_targets', { p_users: users, p_tipo: tipo });
      byTipo.set(tipo, new Map(ts.map((t) => [t.user_id, t])));
    }
    const names = actors.length ? await rpc<Record<string, string>>(db, 'svc_display_names', { p_users: actors }) : {};
    await runBatch('push', pushes, async (p) => {
      if (p.message.broadcast === 'novedad') {
        await rpc(db, 'svc_expand_broadcast', { p_post: p.message.post_id, p_titulo: p.message.titulo });
        return;
      }
      const tipo = String(p.message.tipo);
      const t = byTipo.get(tipo)?.get(String(p.message.user_id));
      if (!t || !t.wants || !t.tokens.length) return;
      const payload = (p.message.payload ?? {}) as Record<string, unknown>;
      const { title, body } = renderPush(tipo, names[String(p.message.actor_id)] ?? null, 1, payload);
      const route = payload.post_id ? `/post/${payload.post_id}` : tipo === 'nuevo_seguidor' ? '/notificaciones' : '/';
      await deliver(t, title, body, { tipo, route, notification_id: String(p.message.notification_id ?? '') },
        payload.post_id ? `${tipo}-${payload.post_id}` : undefined);
      stats.notificaciones++;
    });
    if (pushes.length < batch) break;
  }

  if (invalid.size) {
    stats.tokens_invalidos = await rpc<number>(db, 'svc_drop_tokens', { p_tokens: [...invalid] });
  }
  return stats;
}

if (import.meta.main) {
  Deno.serve({ port: Number(Deno.env.get("FN_PORT") ?? 8000) }, handle(async (req) => {
    if (!isServiceCall(req)) throw new HttpError(401, 'unauthorized', 'Solo servicio');
    const stats = await dispatch(serviceClient(), pushFromEnv());
    log('push_dispatch', stats);
    return json(req, stats);
  }));
}
