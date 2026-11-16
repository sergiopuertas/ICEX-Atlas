// Login OIDC end-to-end contra Supabase local + IdP de pruebas, sin navegador.
// Reproduce lo que hace supabase_flutter: signInWithOAuth('custom:icex-alumni') con PKCE.
//
//   NODE_EXTRA_CA_CERTS=docker/certs/dev-ca.crt node scripts/e2e/oidc-login.mjs ana
//
// Exporta loginAs(sub) → { session, error } para los tests de integración.
import { createHash, randomBytes } from 'node:crypto';

const API_URL = process.env.SUPABASE_URL ?? 'http://127.0.0.1:54321';
const ANON_KEY = process.env.SUPABASE_ANON_KEY;
const REDIRECT = process.env.REDIRECT_TO ?? 'http://127.0.0.1:3000/auth/callback';

const b64url = (b) => b.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

class Jar {
  #c = new Map();
  store(url, res) {
    const host = new URL(url).host;
    for (const sc of res.headers.getSetCookie?.() ?? []) {
      const [kv] = sc.split(';');
      const i = kv.indexOf('=');
      const m = this.#c.get(host) ?? new Map();
      m.set(kv.slice(0, i).trim(), kv.slice(i + 1));
      this.#c.set(host, m);
    }
  }
  header(url) {
    const m = this.#c.get(new URL(url).host);
    return m ? [...m].map(([k, v]) => `${k}=${v}`).join('; ') : '';
  }
}

async function go(jar, url, init = {}) {
  const res = await fetch(url, { ...init, redirect: 'manual', headers: { ...(init.headers ?? {}), cookie: jar.header(url) } });
  jar.store(url, res);
  return res;
}

export async function loginAs(sub, { anonKey = ANON_KEY } = {}) {
  if (!anonKey) throw new Error('Falta SUPABASE_ANON_KEY');
  const jar = new Jar();
  const verifier = b64url(randomBytes(32));
  const challenge = b64url(createHash('sha256').update(verifier).digest());
  let url = `${API_URL}/auth/v1/authorize?provider=custom:icex-alumni&redirect_to=${encodeURIComponent(REDIRECT)}`
    + `&code_challenge=${challenge}&code_challenge_method=s256`;

  for (let hop = 0; hop < 20; hop++) {
    if (url.startsWith(REDIRECT)) break;
    let res = await go(jar, url, { headers: { apikey: anonKey } });
    if (res.status === 200 && url.includes('/interaction/')) {
      // Pantalla de login del IdP: elegimos el usuario semilla.
      const action = new URL(url).pathname + '/login';
      res = await go(jar, new URL(action, url).toString(), {
        method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: `sub=${encodeURIComponent(sub)}`,
      });
    }
    const loc = res.headers.get('location');
    if (!loc) return { session: null, error: `Flujo interrumpido (${res.status}) en ${url}: ${(await res.text()).slice(0, 300)}` };
    url = new URL(loc, url).toString();
  }

  const back = new URL(url);
  const params = new URLSearchParams(back.search + '&' + back.hash.replace(/^#/, ''));
  if (params.get('error')) {
    return { session: null, error: params.get('error_description') ?? params.get('error'), errorCode: params.get('error_code') };
  }
  const code = params.get('code');
  const tok = await fetch(`${API_URL}/auth/v1/token?grant_type=pkce`, {
    method: 'POST', headers: { apikey: anonKey, 'content-type': 'application/json' },
    body: JSON.stringify({ auth_code: code, code_verifier: verifier }),
  });
  const body = await tok.json();
  if (!tok.ok) return { session: null, error: body.msg ?? body.error_description ?? JSON.stringify(body) };
  return { session: body, error: null };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const sub = process.argv[2] ?? 'ana';
  const { session, error, errorCode } = await loginAs(sub);
  if (error) { console.log(JSON.stringify({ ok: false, sub, error, errorCode })); process.exit(2); }
  const payload = JSON.parse(Buffer.from(session.access_token.split('.')[1], 'base64url').toString());
  console.log(JSON.stringify({ ok: true, sub, user_id: session.user.id, user_role: payload.user_role, icex_member: payload.icex_member }));
}
