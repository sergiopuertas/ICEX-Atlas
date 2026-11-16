import { deepStrictEqual, ok, strictEqual } from 'node:assert/strict';
import { dispatch } from '../push-dispatcher/index.ts';
import { sync } from '../membership-sync/index.ts';
import { MockPushSender, renderPush } from '../_shared/push.ts';
import { fakeDb } from './fake_db.ts';

Deno.test('renderPush: no muestra el contenido de mensajes privados y agrupa', () => {
  deepStrictEqual(renderPush('mensaje', 'Ana', 1, {}), { title: 'Ana', body: 'Te ha enviado un mensaje' });
  strictEqual(renderPush('recomendacion', 'Ana', 3, {}).body, 'Ana y 2 más recomendaron tu publicación');
  strictEqual(renderPush('novedad', null, 1, { titulo: 'Reunión anual' }).body, 'Reunión anual');
});

Deno.test('dispatch: push de mensaje solo a destinatarios sin conexión; tokens inválidos se eliminan', async () => {
  const acked: Record<string, unknown[]> = {};
  const { db, calls } = fakeDb({
    svc_queue_read: (a) => a.p_queue === 'message_events'
      ? [{ msg_id: 1, read_ct: 1, message: { conversation_id: 'c1', remitente_id: 'ana', destinatarios: ['bea', 'carla'] } }]
      : [],
    svc_push_targets: () => [
      { user_id: 'bea', online: false, wants: true, tokens: ['tok-bea', 'invalid-viejo'] },
      { user_id: 'carla', online: true, wants: true, tokens: ['tok-carla'] },
    ],
    svc_display_names: () => ({ ana: 'Ana Ortega' }),
    svc_queue_ack: (a) => { acked[String(a.p_queue)] = a.p_ids as unknown[]; return 1; },
    svc_drop_tokens: (a) => (a.p_tokens as string[]).length,
  });
  const sender = new MockPushSender();
  const stats = await dispatch(db, sender);
  deepStrictEqual(sender.sent.map((s) => s.token), ['tok-bea', 'invalid-viejo']);
  strictEqual(sender.sent[0].data.route, '/mensajes/c1');
  strictEqual(stats.omitidos_online, 1);
  strictEqual(stats.enviados, 1);
  strictEqual(stats.tokens_invalidos, 1);
  deepStrictEqual(acked.message_events, [1]);
  ok(calls.some((c) => c.fn === 'svc_drop_tokens'));
});

Deno.test('dispatch: notificaciones respetan preferencias y expanden novedades', async () => {
  const { db, calls } = fakeDb({
    svc_queue_read: (a) => a.p_queue === 'push' ? [
      { msg_id: 7, read_ct: 1, message: { broadcast: 'novedad', post_id: 'p9', titulo: 'Reunión' } },
      { msg_id: 8, read_ct: 1, message: { user_id: 'bea', tipo: 'recomendacion', actor_id: 'ana', payload: { post_id: 'p1' } } },
      { msg_id: 9, read_ct: 1, message: { user_id: 'carla', tipo: 'recomendacion', actor_id: 'ana', payload: { post_id: 'p1' } } },
    ] : [],
    svc_expand_broadcast: () => 120,
    svc_push_targets: () => [
      { user_id: 'bea', online: true, wants: true, tokens: ['tok-bea'] },
      { user_id: 'carla', online: false, wants: false, tokens: ['tok-carla'] },
    ],
    svc_display_names: () => ({ ana: 'Ana' }),
    svc_queue_ack: () => 3,
  });
  const sender = new MockPushSender();
  await dispatch(db, sender);
  deepStrictEqual(sender.sent.map((s) => s.token), ['tok-bea'], 'carla no quiere push social');
  strictEqual(sender.sent[0].collapseKey, 'recomendacion-p1');
  ok(calls.some((c) => c.fn === 'svc_expand_broadcast' && c.args.p_post === 'p9'));
});

Deno.test('membership-sync: revoca solo "inactive", nunca "unknown"', async () => {
  const revoked: string[] = [];
  let page = 0;
  const { db } = fakeDb({
    svc_member_subjects: () => page++ === 0
      ? Array.from({ length: 40 }, (_, i) => ({ user_id: `u${i}`, wp_subject: `s${i}` }))
      : [],
    svc_revoke_member: (a) => { revoked.push(String(a.p_user)); return null; },
  });
  const r = await sync(db, (subs) => Promise.resolve(Object.fromEntries(subs.map((s) =>
    [s, s === 's3' ? 'inactive' : s === 's4' ? 'unknown' : 'active'] as const))));
  deepStrictEqual(revoked, ['u3']);
  deepStrictEqual(r, { checked: 40, revoked: 1, aborted: false });
});

Deno.test('membership-sync: freno de seguridad ante bajas masivas', async () => {
  let page = 0;
  const { db, calls } = fakeDb({
    svc_member_subjects: () => page++ === 0 ? Array.from({ length: 100 }, (_, i) => ({ user_id: `u${i}`, wp_subject: `s${i}` })) : [],
    svc_revoke_member: () => null,
  });
  const r = await sync(db, (subs) => Promise.resolve(Object.fromEntries(subs.map((s) => [s, 'inactive'] as const))));
  strictEqual(r.aborted, true);
  ok(!calls.some((c) => c.fn === 'svc_revoke_member'));
});
