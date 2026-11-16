// Envío de push con Firebase Cloud Messaging (API HTTP v1; APNs vía FCM en iOS).
//   PUSH_PROVIDER = mock | fcm
//   FCM_SERVICE_ACCOUNT_JSON = JSON de la cuenta de servicio (secreto de Edge Functions)
// En local `mock` registra el envío (sin contenido personal) y lo guarda en memoria para tests.

export interface PushMessage {
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
  collapseKey?: string;
}

export interface PushResult { ok: boolean; invalidToken?: boolean }

export interface PushSender {
  readonly name: string;
  send(m: PushMessage): Promise<PushResult>;
}

export class MockPushSender implements PushSender {
  readonly name = 'mock';
  readonly sent: PushMessage[] = [];
  send(m: PushMessage): Promise<PushResult> {
    this.sent.push(m);
    if (m.token.startsWith('invalid-')) return Promise.resolve({ ok: false, invalidToken: true });
    return Promise.resolve({ ok: true });
  }
}

const b64url = (b: Uint8Array | string) =>
  btoa(typeof b === 'string' ? b : String.fromCharCode(...b)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

export class FcmSender implements PushSender {
  readonly name = 'fcm';
  #token: { value: string; exp: number } | null = null;
  constructor(private sa: { client_email: string; private_key: string; project_id: string }) {}

  async #accessToken(): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    if (this.#token && this.#token.exp - 60 > now) return this.#token.value;
    const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
    const claims = b64url(JSON.stringify({
      iss: this.sa.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
    }));
    const pem = this.sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
    const key = await crypto.subtle.importKey('pkcs8', Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
    const sig = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${header}.${claims}`)));
    const r = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${header}.${claims}.${b64url(sig)}`,
    });
    if (!r.ok) throw new Error(`OAuth FCM ${r.status}`);
    const j = await r.json();
    this.#token = { value: j.access_token, exp: now + j.expires_in };
    return j.access_token;
  }

  async send(m: PushMessage): Promise<PushResult> {
    const r = await fetch(`https://fcm.googleapis.com/v1/projects/${this.sa.project_id}/messages:send`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${await this.#accessToken()}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: {
          token: m.token,
          notification: { title: m.title, body: m.body },
          data: m.data,
          android: { collapse_key: m.collapseKey, priority: 'high', notification: { channel_id: 'icex_atlas' } },
          apns: { headers: m.collapseKey ? { 'apns-collapse-id': m.collapseKey } : {}, payload: { aps: { sound: 'default' } } },
        },
      }),
    });
    if (r.ok) return { ok: true };
    const status = (await r.json().catch(() => ({})))?.error?.status;
    return { ok: false, invalidToken: r.status === 404 || status === 'UNREGISTERED' || status === 'INVALID_ARGUMENT' };
  }
}

export function pushFromEnv(): PushSender {
  if ((Deno.env.get('PUSH_PROVIDER') ?? 'mock') === 'fcm') {
    return new FcmSender(JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT_JSON') ?? '{}'));
  }
  return new MockPushSender();
}

/** Textos de notificación (sin el contenido de mensajes privados en la pantalla de bloqueo). */
export function renderPush(tipo: string, actorName: string | null, total: number, payload: Record<string, unknown>):
  { title: string; body: string } {
  const quien = actorName ?? 'Un alumni';
  const mas = total > 1 ? ` y ${total - 1} más` : '';
  switch (tipo) {
    case 'mensaje': return { title: quien, body: 'Te ha enviado un mensaje' };
    case 'nuevo_seguidor': return { title: 'Nuevo seguidor', body: `${quien}${mas} ${total > 1 ? 'empezaron' : 'empezó'} a seguirte` };
    case 'recomendacion': return { title: 'Recomendación', body: `${quien}${mas} ${total > 1 ? 'recomendaron' : 'recomendó'} tu publicación` };
    case 'comentario': return { title: 'Comentario', body: `${quien}${mas} ${total > 1 ? 'comentaron' : 'comentó'} tu publicación` };
    case 'evento': return { title: 'Evento', body: String(payload.titulo ?? 'Novedades de tu club') };
    case 'novedad': return { title: 'Novedad de la asociación', body: String(payload.titulo ?? 'Nuevo comunicado') };
    default: return { title: 'ICEX Alumni', body: 'Tienes novedades' };
  }
}
