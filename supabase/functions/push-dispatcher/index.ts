// push-dispatcher · invocada por pg_cron cada minuto (service_role).
// 1) message_events → push "mensaje" a destinatarios sin conexión (heartbeat > 90 s) que lo desean.
// 2) push → notificaciones ya filtradas por preferencias; las novedades se expanden por socio.
// Elimina tokens inválidos y confirma (ack) los mensajes procesados.
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

export async function dispatch(db: Db, sender: PushSender, batch = 200) {
  const stats = { mensajes: 0, notificaciones: 0, enviados: 0, tokens_invalidos: 0, omitidos_online: 0 };
  const invalid: string[] = [];

  const deliver = async (target: Target, title: string, body: string, data: Record<string, string>, collapseKey?: string) => {
    for (const token of target.tokens) {
      const r = await sender.send({ token, title, body, data, collapseKey });
      if (r.ok) stats.enviados++;
      else if (r.invalidToken) invalid.push(token);
    }
  };

  // ---------------------------------------------------------- mensajes -------
  const events = await rpc<QueueMsg[]>(db, 'svc_queue_read', { p_queue: 'message_events', p_qty: batch, p_vt: 120 });
  if (events.length) {
    const recipients = [...new Set(events.flatMap((e) => (e.message.destinatarios as string[]) ?? []))];
    const senders = [...new Set(events.map((e) => String(e.message.remitente_id)))];
    const [targets, names] = await Promise.all([
      rpc<Target[]>(db, 'svc_push_targets', { p_users: recipients, p_tipo: 'mensaje' }),
      rpc<Record<string, string>>(db, 'svc_display_names', { p_users: senders }),
    ]);
    const byId = new Map(targets.map((t) => [t.user_id, t]));
    for (const e of events) {
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
    }
    await rpc(db, 'svc_queue_ack', { p_queue: 'message_events', p_ids: events.map((e) => e.msg_id) });
  }

  // ------------------------------------------------------ notificaciones ------
  const pushes = await rpc<QueueMsg[]>(db, 'svc_queue_read', { p_queue: 'push', p_qty: batch, p_vt: 120 });
  if (pushes.length) {
    for (const p of pushes.filter((p) => p.message.broadcast === 'novedad')) {
      await rpc(db, 'svc_expand_broadcast', { p_post: p.message.post_id, p_titulo: p.message.titulo });
    }
    const personal = pushes.filter((p) => !p.message.broadcast);
    const users = [...new Set(personal.map((p) => String(p.message.user_id)))];
    const actors = [...new Set(personal.map((p) => p.message.actor_id).filter(Boolean).map(String))];
    const byTipo = new Map<string, Target[]>();
    for (const tipo of [...new Set(personal.map((p) => String(p.message.tipo)))]) {
      byTipo.set(tipo, await rpc<Target[]>(db, 'svc_push_targets', { p_users: users, p_tipo: tipo }));
    }
    const names = actors.length ? await rpc<Record<string, string>>(db, 'svc_display_names', { p_users: actors }) : {};
    for (const p of personal) {
      const tipo = String(p.message.tipo);
      const t = byTipo.get(tipo)?.find((x) => x.user_id === p.message.user_id);
      if (!t || !t.wants || !t.tokens.length) continue;
      const payload = (p.message.payload ?? {}) as Record<string, unknown>;
      const { title, body } = renderPush(tipo, names[String(p.message.actor_id)] ?? null, 1, payload);
      const route = payload.post_id ? `/post/${payload.post_id}` : tipo === 'nuevo_seguidor' ? '/notificaciones' : '/';
      await deliver(t, title, body, { tipo, route, notification_id: String(p.message.notification_id ?? '') },
        payload.post_id ? `${tipo}-${payload.post_id}` : undefined);
      stats.notificaciones++;
    }
    await rpc(db, 'svc_queue_ack', { p_queue: 'push', p_ids: pushes.map((p) => p.msg_id) });
  }

  if (invalid.length) {
    stats.tokens_invalidos = await rpc<number>(db, 'svc_drop_tokens', { p_tokens: [...new Set(invalid)] });
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
