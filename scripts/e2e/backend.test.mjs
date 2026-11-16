// Pruebas de integración de extremo a extremo contra la Supabase local + IdP de pruebas.
// Requisitos: `supabase start`, `./scripts/setup-local.sh`, funciones servidas
// (por defecto en el edge-runtime: http://127.0.0.1:54321/functions/v1; o FUNCTIONS_URL con
// scripts/serve-functions-host.sh) y NODE_EXTRA_CA_CERTS=docker/certs/dev-ca.crt.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createClient } from '@supabase/supabase-js';
import { loginAs } from './oidc-login.mjs';

const URL_ = process.env.SUPABASE_URL ?? 'http://127.0.0.1:54321';
const ANON = process.env.SUPABASE_ANON_KEY;
const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY;
const FUNCTIONS = process.env.FUNCTIONS_URL;          // p. ej. http://127.0.0.1:54400 (host) o vacío (edge-runtime)
const IDP = process.env.OIDC_ISSUER ?? 'https://idp.icex-atlas.test:9010';

// UUIDv7 como en la app (paquete `uuid` de Dart).
function uuidv7() {
  const b = Buffer.from(randomUUID().replace(/-/g, ''), 'hex');
  const ms = BigInt(Date.now());
  for (let i = 0; i < 6; i++) b[i] = Number((ms >> BigInt(8 * (5 - i))) & 0xffn);
  b[6] = (b[6] & 0x0f) | 0x70; b[8] = (b[8] & 0x3f) | 0x80;
  const h = b.toString('hex');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}

async function sessionFor(sub) {
  const { session, error } = await loginAs(sub, { anonKey: ANON });
  assert.equal(error, null, `login de ${sub}: ${error}`);
  const client = createClient(URL_, ANON, { db: { schema: 'api' }, auth: { persistSession: false, autoRefreshToken: false } });
  await client.auth.setSession({ access_token: session.access_token, refresh_token: session.refresh_token });
  await client.realtime.setAuth(session.access_token);
  return { client, session, uid: session.user.id };
}

const fnUrl = (name) => FUNCTIONS ? `${FUNCTIONS.replace(/544\d\d$/, '')}${portOf(name)}` : `${URL_}/functions/v1/${name}`;
const PORTS = { orientador: 54400, 'orientador-indexer': 54401, 'push-dispatcher': 54402, 'media-upload': 54403, 'account-delete': 54404, 'membership-sync': 54405 };
function portOf(name) { return PORTS[name]; }

async function callFn(name, token, body, headers = {}) {
  const r = await fetch(fnUrl(name), {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, apikey: ANON, 'Content-Type': 'application/json', ...headers },
    body: body instanceof Uint8Array ? body : JSON.stringify(body ?? {}),
  });
  return { status: r.status, body: await r.json().catch(() => null) };
}

test('Un no socio no puede iniciar sesión (hook before_user_created)', async () => {
  const { session, error } = await loginAs('pedro', { anonKey: ANON });
  assert.equal(session, null);
  assert.match(error, /icex_member_not_verified/);
});

test('Recorrido completo: login → feed → publicar → seguir → mensaje en tiempo real', async () => {
  const ana = await sessionFor('ana');
  const javier = await sessionFor('javier');

  // JWT con el rol añadido por el custom access token hook
  const claims = JSON.parse(Buffer.from(ana.session.access_token.split('.')[1], 'base64url'));
  assert.equal(claims.user_role, 'socio');

  // Feed
  const feed = await ana.client.rpc('get_feed', { p_cursor: null, p_limit: 20 });
  assert.equal(feed.error, null);
  assert.equal(feed.data.items.length, 20);
  assert.ok(feed.data.destacadas.length >= 1, 'novedad fijada arriba');
  const page2 = await ana.client.rpc('get_feed', { p_cursor: feed.data.next_cursor, p_limit: 20 });
  assert.equal(page2.error, null);
  assert.ok(!page2.data.items.some((p) => feed.data.items.find((q) => q.id === p.id)), 'keyset sin duplicados');

  // Publicar (idempotente por UUIDv7)
  const postId = uuidv7();
  const pub = await ana.client.rpc('create_post', { p_id: postId, p_texto: 'Prueba de integración 🚀', p_tipo: 'logro' });
  assert.equal(pub.error, null);
  const again = await ana.client.rpc('create_post', { p_id: postId, p_texto: 'Prueba de integración 🚀', p_tipo: 'logro' });
  assert.equal(again.data.id, postId);

  // Seguir (Javier sigue a Ana) y ver su publicación en el feed
  await javier.client.rpc('unfollow', { p_user: ana.uid });
  const f = await javier.client.rpc('follow', { p_user: ana.uid });
  assert.equal(f.error, null);
  assert.equal(f.data.is_following, true);
  const jfeed = await javier.client.rpc('get_feed', { p_cursor: null, p_limit: 10 });
  assert.ok(jfeed.data.items.some((p) => p.id === postId), 'la publicación aparece en el feed del seguidor');

  // Mensaje en tiempo real: Javier escucha el canal privado de la conversación
  const convId = (await ana.client.rpc('find_direct_conversation', { p_to: javier.uid })).data
    ?? (await ana.client.rpc('send_message', { p_id: uuidv7(), p_cuerpo: 'Hola Javier', p_to: javier.uid, p_categoria: 'networking' })).data.conversation_id;
  const received = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('No llegó el mensaje por Realtime en 10 s')), 10_000);
    const ch = javier.client.channel(`conversation:${convId}`, { config: { private: true } })
      .on('broadcast', { event: 'message.created' }, (msg) => { clearTimeout(timer); resolve({ msg, ch }); })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
          const sent = await ana.client.rpc('send_message', { p_id: msgId, p_cuerpo: 'Mensaje en tiempo real', p_conversation_id: convId });
          if (sent.error) reject(new Error(sent.error.message));
        }
      });
  });
  const msgId = uuidv7();
  const { msg, ch } = await received;
  assert.equal(msg.payload.id, msgId);
  assert.equal(msg.payload.cuerpo, 'Mensaje en tiempo real');
  await javier.client.removeChannel(ch);

  // Un tercero NO puede suscribirse al canal privado de esa conversación
  const laura = await sessionFor('laura');
  const denied = await new Promise((resolve) => {
    const ch2 = laura.client.channel(`conversation:${convId}`, { config: { private: true } })
      .subscribe((status, err) => { if (status !== 'SUBSCRIBED') resolve({ status, err, ch2 }); else resolve({ status, ch2 }); });
    setTimeout(() => resolve({ status: 'TIMEOUT', ch2 }), 8000);
  });
  assert.notEqual(denied.status, 'SUBSCRIBED', 'canal privado protegido por RLS');
  await laura.client.removeChannel(denied.ch2);

  // Leído (doble check)
  const read = await javier.client.rpc('mark_read', { p_conversation: convId, p_message_id: msgId });
  assert.equal(read.error, null);
  const conv = await ana.client.rpc('get_conversation', { p_conversation: convId });
  assert.equal(conv.data.otro.ultimo_leido_id, msgId);

  // Limpieza
  await ana.client.rpc('delete_post', { p_id: postId });
});

test('Edge Functions: orientador, media-upload (sin EXIF) y push-dispatcher', { skip: !SERVICE }, async () => {
  const ana = await sessionFor('ana');
  const token = ana.session.access_token;

  const o = await callFn('orientador', token, { fase: 'fase_1', pais: 'Alemania', sector: 'Energía', consulta: 'Preparar la entrevista de Fase II' });
  assert.equal(o.status, 200, JSON.stringify(o.body));
  assert.ok(o.body.pasos.length >= 3);
  assert.ok(o.body.alumni.length >= 1 && o.body.alumni[0].slug, 'sugiere alumni reales con enlace a perfil');

  // JPEG con EXIF "GPS"
  const seg = (m, p) => [0xff, m, (p.length + 2) >> 8, (p.length + 2) & 0xff, ...p];
  const asc = (s) => [...s].map((c) => c.charCodeAt(0));
  const jpeg = new Uint8Array([0xff, 0xd8, ...seg(0xe1, [...asc('Exif'), 0, 0, ...asc('GPS 40N 3W')]), ...seg(0xda, [1, 2, 3]), 9, 9, 0xff, 0xd9]);
  const up = await callFn('media-upload', token, jpeg, { 'Content-Type': 'image/jpeg' });   // bucket por defecto: post-media
  assert.equal(up.status, 201, JSON.stringify(up.body));
  const svc = createClient(URL_, SERVICE, { auth: { persistSession: false } });
  const dl = await svc.storage.from(up.body.bucket).download(up.body.path);
  const bytes = Buffer.from(await dl.data.arrayBuffer());
  assert.equal(bytes.includes(Buffer.from('GPS')), false, 'EXIF eliminado en el servidor');
  const svg = await callFn('media-upload', token, new TextEncoder().encode('<svg/>'), { 'Content-Type': 'image/svg+xml' });
  assert.equal(svg.status, 415, 'el tipo real se valida por magic bytes');
  await svc.storage.from(up.body.bucket).remove([up.body.path]);

  const d = await callFn('push-dispatcher', SERVICE, {});
  assert.equal(d.status, 200);
  const unauth = await callFn('push-dispatcher', token, {});
  assert.equal(unauth.status, 401, 'las funciones de servicio rechazan JWT de socio');
});

test('Sincronía diaria con WordPress revoca a quien se da de baja', { skip: !SERVICE }, async () => {
  await fetch(`${IDP}/dev/alta/nueva`, { method: 'POST' });
  const nueva = await sessionFor('nueva');                      // alta nueva por OIDC
  assert.equal((await nueva.client.rpc('me')).error, null);
  await fetch(`${IDP}/dev/baja/nueva`, { method: 'POST' });     // WordPress: baja
  const s = await callFn('membership-sync', SERVICE, {});
  assert.equal(s.status, 200, JSON.stringify(s.body));
  assert.ok(s.body.revoked >= 1);
  const after = await nueva.client.rpc('me');
  assert.equal(after.error?.code, '42501', 'pierde el acceso inmediatamente (RLS)');
  const relogin = await loginAs('nueva', { anonKey: ANON });
  assert.ok(relogin.error, 'y no puede volver a obtener sesión');
  // restaurar para siguientes ejecuciones
  const svc = createClient(URL_, SERVICE, { auth: { persistSession: false } });
  await svc.auth.admin.deleteUser(nueva.uid);
  await fetch(`${IDP}/dev/alta/nueva`, { method: 'POST' });
});
