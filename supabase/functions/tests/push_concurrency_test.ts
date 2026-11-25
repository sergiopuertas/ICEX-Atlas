// push-dispatcher bajo volumen y fallos: vaciado por lotes, envíos en paralelo acotados,
// fallos aislados, mensajes «veneno», presupuesto de tiempo y refresco único del token de FCM.
import { deepStrictEqual, ok, strictEqual } from 'node:assert/strict';
import { dispatch, pool } from '../push-dispatcher/index.ts';
import { FcmSender, type PushMessage, type PushResult, type PushSender } from '../_shared/push.ts';
import { fakeDb } from './fake_db.ts';

type Msg = { msg_id: number; read_ct: number; message: Record<string, unknown> };

/** Cola simulada con visibilidad: lo leído no se vuelve a leer hasta el ack o un reset. */
function queue(msgs: Msg[]) {
  const pending = [...msgs];
  const acked: number[] = [];
  return {
    acked,
    read: (qty: number) => pending.splice(0, qty),
    ack: (ids: number[]) => { acked.push(...ids); return ids.length; },
  };
}

class SlowSender implements PushSender {
  readonly name = 'slow';
  inFlight = 0;
  maxInFlight = 0;
  sent: string[] = [];
  constructor(private ms = 5, private failing = new Set<string>()) {}
  async send(m: PushMessage): Promise<PushResult> {
    this.inFlight++;
    this.maxInFlight = Math.max(this.maxInFlight, this.inFlight);
    await new Promise((r) => setTimeout(r, this.ms));
    this.inFlight--;
    if (this.failing.has(m.token)) throw new Error('red caída');
    this.sent.push(m.token);
    return { ok: true };
  }
}

const offline = (ids: string[]) => ids.map((id) => ({ user_id: id, online: false, wants: true, tokens: [`tok-${id}`] }));

Deno.test('pool: nunca supera el límite y procesa todo', async () => {
  let running = 0, max = 0;
  const done: number[] = [];
  await pool(Array.from({ length: 50 }, (_, i) => i), 7, async (i) => {
    running++; max = Math.max(max, running);
    await new Promise((r) => setTimeout(r, 1));
    running--; done.push(i);
  });
  strictEqual(max, 7);
  strictEqual(done.length, 50);
});

Deno.test('dispatch: vacía la cola en varios lotes (antes: 200 por minuto como máximo)', async () => {
  const q = queue(Array.from({ length: 23 }, (_, i) => ({
    msg_id: i, read_ct: 1, message: { conversation_id: `c${i}`, remitente_id: 'ana', destinatarios: [`u${i}`] },
  })));
  const { db } = fakeDb({
    svc_queue_read: (a) => a.p_queue === 'message_events' ? q.read(Number(a.p_qty)) : [],
    svc_push_targets: (a) => offline(a.p_users as string[]),
    svc_display_names: () => ({ ana: 'Ana' }),
    svc_queue_ack: (a) => q.ack(a.p_ids as number[]),
  });
  const sender = new SlowSender(1);
  const stats = await dispatch(db, sender, { batch: 5 });
  strictEqual(stats.mensajes, 23);
  strictEqual(stats.lotes, 5);
  strictEqual(q.acked.length, 23);
  strictEqual(new Set(sender.sent).size, 23, 'cada destinatario recibe exactamente un push');
});

Deno.test('dispatch: envíos en paralelo acotados (rápido con FCM lento, sin desbordar)', async () => {
  const q = queue(Array.from({ length: 64 }, (_, i) => ({
    msg_id: i, read_ct: 1, message: { conversation_id: `c${i}`, remitente_id: 'ana', destinatarios: [`u${i}`] },
  })));
  const { db } = fakeDb({
    svc_queue_read: (a) => a.p_queue === 'message_events' ? q.read(Number(a.p_qty)) : [],
    svc_push_targets: (a) => offline(a.p_users as string[]),
    svc_display_names: () => ({}),
    svc_queue_ack: (a) => q.ack(a.p_ids as number[]),
  });
  const sender = new SlowSender(10);
  const t0 = performance.now();
  await dispatch(db, sender, { concurrency: 16 });
  const ms = performance.now() - t0;
  strictEqual(sender.maxInFlight, 16);
  ok(ms < 64 * 10 / 2, `en paralelo (${ms.toFixed(0)} ms, en serie serían ${64 * 10} ms)`);
});

Deno.test('dispatch: un token que falla no tumba el lote ni provoca reenvíos al resto', async () => {
  const q = queue([{ msg_id: 1, read_ct: 1, message: { conversation_id: 'c', remitente_id: 'ana', destinatarios: ['a', 'b', 'c'] } }]);
  const { db } = fakeDb({
    svc_queue_read: (a) => a.p_queue === 'message_events' ? q.read(Number(a.p_qty)) : [],
    svc_push_targets: (a) => offline(a.p_users as string[]),
    svc_display_names: () => ({}),
    svc_queue_ack: (a) => q.ack(a.p_ids as number[]),
  });
  const sender = new SlowSender(1, new Set(['tok-b']));
  const stats = await dispatch(db, sender);
  deepStrictEqual(sender.sent.sort(), ['tok-a', 'tok-c']);
  strictEqual(stats.fallidos, 1);
  deepStrictEqual(q.acked, [1], 'confirmado: no se reenvía a a y c');
});

Deno.test('dispatch: un mensaje que siempre falla se reintenta y, tras maxReads, se descarta', async () => {
  const broken = (read_ct: number) => ({ msg_id: 9, read_ct, message: { broadcast: 'novedad', post_id: 'p', titulo: 't' } });
  for (const [readCt, expectAck] of [[1, false], [5, true]] as const) {
    const q = queue([broken(readCt), { msg_id: 10, read_ct: 1, message: { user_id: 'u1', tipo: 'comentario', actor_id: 'ana', payload: {} } }]);
    const { db } = fakeDb({
      svc_queue_read: (a) => a.p_queue === 'push' ? q.read(Number(a.p_qty)) : [],
      svc_expand_broadcast: () => { throw new Error('fallo permanente'); },
      svc_push_targets: (a) => offline(a.p_users as string[]),
      svc_display_names: () => ({ ana: 'Ana' }),
      svc_queue_ack: (a) => q.ack(a.p_ids as number[]),
    });
    const stats = await dispatch(db, new SlowSender(1), { maxReads: 5 });
    ok(q.acked.includes(10), 'el resto del lote se confirma');
    strictEqual(q.acked.includes(9), expectAck, `read_ct=${readCt}`);
    strictEqual(stats.descartados, expectAck ? 1 : 0);
  }
});

Deno.test('dispatch: respeta el presupuesto de tiempo (no se solapa con la siguiente ejecución)', async () => {
  let clock = 0;
  let reads = 0;
  const { db } = fakeDb({
    svc_queue_read: (a) => {
      if (a.p_queue !== 'message_events') return [];
      reads++;
      clock += 20_000;   // cada lote «tarda» 20 s
      return Array.from({ length: 2 }, (_, i) => ({ msg_id: reads * 10 + i, read_ct: 1, message: { destinatarios: [] } }));
    },
    svc_push_targets: () => [],
    svc_display_names: () => ({}),
    svc_queue_ack: () => 2,
  });
  await dispatch(db, new SlowSender(0), { batch: 2, budgetMs: 45_000, now: () => clock });
  strictEqual(reads, 3, 'lee mientras queda presupuesto y para');
});

Deno.test('FcmSender: con envíos simultáneos el token OAuth se pide una sola vez', async () => {
  const kp = await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true, ['sign', 'verify']);
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey('pkcs8', kp.privateKey));
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...pkcs8))}\n-----END PRIVATE KEY-----`;
  let tokenCalls = 0, sends = 0;
  const realFetch = globalThis.fetch;
  globalThis.fetch = (async (input: string | URL | Request) => {
    const url = String(input instanceof Request ? input.url : input);
    if (url.includes('oauth2')) {
      tokenCalls++;
      await new Promise((r) => setTimeout(r, 20));
      return new Response(JSON.stringify({ access_token: 'at', expires_in: 3600 }));
    }
    sends++;
    return new Response('{}');
  }) as typeof fetch;
  try {
    const fcm = new FcmSender({ client_email: 'x@y', private_key: pem, project_id: 'p' });
    const results = await Promise.all(Array.from({ length: 30 }, (_, i) =>
      fcm.send({ token: `t${i}`, title: 'a', body: 'b', data: {} })));
    ok(results.every((r) => r.ok));
    strictEqual(tokenCalls, 1);
    strictEqual(sends, 30);
  } finally {
    globalThis.fetch = realFetch;
  }
});
