// Proveedor OIDC de pruebas para ICEX Atlas (SOLO desarrollo local y CI).
// Imita a la web WordPress de ICEX Alumni con el plugin "OpenID Connect Server":
// emite el claim `icex_member_verified` (como hará wordpress/oidc-claims.php).
//
// Variables:
//   OIDC_ISSUER        (por defecto http://host.docker.internal:9010)
//   OIDC_PORT          (9010)
//   OIDC_CLIENT_ID     (supabase-local)
//   OIDC_CLIENT_SECRET (supabase-local-secret)
//   OIDC_REDIRECT_URIS (coma; por defecto el callback de Supabase local)
import Provider from 'oidc-provider';
import { createServer as createHttpServer } from 'node:http';
import { createServer as createHttpsServer } from 'node:https';
import { readFileSync, existsSync } from 'node:fs';

const ISSUER = process.env.OIDC_ISSUER ?? 'https://host.docker.internal:9010';
// Supabase Auth exige issuer HTTPS: certificado firmado por la CA local de desarrollo (scripts/dev-certs.sh).
const CERT_DIR = process.env.OIDC_CERT_DIR ?? '/certs';
const PORT = Number(process.env.OIDC_PORT ?? 9010);

// Usuarios semilla (ficticios). `ana`, `javier` y `laura` existen en supabase/seed.sql.
export const USERS = {
  ana: { name: 'Ana Ortega Jiménez', email: 'ana.ortega@demo.icexalumni.invalid', icex_member_verified: true, icex_promocion: 49, icex_fase: 'activo' },
  javier: { name: 'Javier Martín Jiménez', email: 'javier.martin@demo.icexalumni.invalid', icex_member_verified: true, icex_promocion: 42, icex_fase: 'activo' },
  laura: { name: 'Laura Gil Navarro', email: 'laura.gil@demo.icexalumni.invalid', icex_member_verified: true, icex_promocion: 28, icex_fase: 'activo' },
  nueva: { name: 'Nuria Becaria Nueva', email: 'nuria.nueva@demo.icexalumni.invalid', icex_member_verified: true, icex_promocion: 51, icex_fase: 'fase_0' },
  pedro: { name: 'Pedro Sin Membresía', email: 'pedro.nosocio@demo.icexalumni.invalid', icex_member_verified: false },
};

const DADOS_DE_BAJA = new Set();

const configuration = {
  clients: [{
    client_id: process.env.OIDC_CLIENT_ID ?? 'supabase-local',
    client_secret: process.env.OIDC_CLIENT_SECRET ?? 'supabase-local-secret',
    redirect_uris: (process.env.OIDC_REDIRECT_URIS ?? 'http://127.0.0.1:54321/auth/v1/callback,http://localhost:54321/auth/v1/callback').split(','),
    grant_types: ['authorization_code', 'refresh_token'],
    response_types: ['code'],
    token_endpoint_auth_method: 'client_secret_post',
  }],
  // En el ID token van también los claims de los scopes (como hace el plugin de WordPress).
  conformIdTokenClaims: false,
  claims: {
    openid: ['sub'],
    profile: ['name', 'icex_member_verified', 'icex_promocion', 'icex_fase'],
    email: ['email', 'email_verified'],
  },
  scopes: ['openid', 'profile', 'email', 'offline_access'],
  pkce: { required: () => false },
  features: { devInteractions: { enabled: false } },
  ttl: { AccessToken: 3600, IdToken: 3600, Interaction: 600, Session: 3600, Grant: 3600 },
  cookies: { keys: ['icex-atlas-oidc-dev-only'] },
  async findAccount(_ctx, sub) {
    const u = USERS[sub];
    if (!u) return undefined;
    return {
      accountId: sub,
      async claims() {
        const c = { sub, name: u.name, email: u.email, email_verified: true, icex_member_verified: u.icex_member_verified && !DADOS_DE_BAJA.has(sub) };
        if (u.icex_promocion) c.icex_promocion = u.icex_promocion;
        if (u.icex_fase) c.icex_fase = u.icex_fase;
        return c;
      },
    };
  },
  interactions: { url: (_ctx, interaction) => `/interaction/${interaction.uid}` },
};

const provider = new Provider(ISSUER, configuration);
provider.proxy = true;

const page = (uid) => `<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>ICEX Alumni · acceso (pruebas)</title>
<style>body{font-family:system-ui;background:#F8F5F2;margin:0;padding:24px;color:#2A2522}
.card{max-width:420px;margin:40px auto;background:#fff;border-radius:12px;padding:24px;border:1px solid #E8E4E0}
h1{font-size:20px}button{display:block;width:100%;margin:8px 0;padding:12px;border-radius:999px;border:1px solid #E8E4E0;background:#fff;font-size:15px;cursor:pointer}
button.v{background:#C8102E;color:#fff;border:0}.n{font-size:13px;color:#6B635C}</style></head>
<body><div class="card"><h1>Web ICEX Alumni (simulada)</h1><p class="n">Proveedor OIDC de pruebas. Elige un usuario semilla.</p>
<form method="post" action="/interaction/${uid}/login">
${Object.entries(USERS).map(([k, u]) => `<button class="${u.icex_member_verified ? 'v' : ''}" name="sub" value="${k}">${u.name}${u.icex_member_verified ? '' : ' (no socio)'}</button>`).join('')}
</form></div></body></html>`;

const readForm = (req) => new Promise((resolve) => {
  let body = '';
  req.on('data', (c) => { body += c; });
  req.on('end', () => resolve(Object.fromEntries(new URLSearchParams(body))));
});

const callback = provider.callback();
const tls = existsSync(`${CERT_DIR}/server.crt`)
  ? { key: readFileSync(`${CERT_DIR}/server.key`), cert: readFileSync(`${CERT_DIR}/server.crt`) }
  : null;
const handler = async (req, res) => {
  try {
    const m = req.url?.match(/^\/interaction\/([^/?]+)(\/login)?/);
    if (m) {
      const details = await provider.interactionDetails(req, res);
      if (!m[2] && req.method === 'GET') {
        res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
        return res.end(page(details.uid));
      }
      if (m[2] && req.method === 'POST') {
        const { sub } = await readForm(req);
        if (!USERS[sub]) {
          return provider.interactionFinished(req, res, { error: 'access_denied', error_description: 'usuario desconocido' });
        }
        const grant = new provider.Grant({ accountId: sub, clientId: details.params.client_id });
        grant.addOIDCScope(String(details.params.scope ?? 'openid profile email'));
        const grantId = await grant.save();
        return provider.interactionFinished(req, res, { login: { accountId: sub }, consent: { grantId } }, { mergeWithLastSubmission: false });
      }
    }
    if (req.url === '/healthz') { res.writeHead(200); return res.end('ok'); }
    // Simula el endpoint de WordPress para la sincronía diaria de membresías (wordpress/README.md).
    if (req.url === '/wp-json/icex-alumni/v1/memberships' && req.method === 'POST') {
      if (req.headers.authorization !== `Bearer ${process.env.WP_SYNC_TOKEN ?? 'dev-sync-token'}`) {
        res.writeHead(401); return res.end('{}');
      }
      let raw = '';
      for await (const c of req) raw += c;
      const { subjects = [] } = JSON.parse(raw || '{}');
      const status = (s) => {
        if (DADOS_DE_BAJA.has(s)) return 'inactive';
        if (USERS[s]) return USERS[s].icex_member_verified ? 'active' : 'inactive';
        return s.startsWith('demo-') ? 'active' : 'unknown';
      };
      const memberships = Object.fromEntries(subjects.slice(0, 1000).map((s) => [s, status(s)]));
      res.writeHead(200, { 'content-type': 'application/json' });
      return res.end(JSON.stringify({ memberships }));
    }
    if (req.url?.startsWith('/dev/baja/') && req.method === 'POST') {   // solo pruebas: simular una baja en WordPress
      DADOS_DE_BAJA.add(decodeURIComponent(req.url.slice('/dev/baja/'.length)));
      res.writeHead(204); return res.end();
    }
    if (req.url?.startsWith('/dev/alta/') && req.method === 'POST') {   // solo pruebas: deshacer la baja
      DADOS_DE_BAJA.delete(decodeURIComponent(req.url.slice('/dev/alta/'.length)));
      res.writeHead(204); return res.end();
    }
    return callback(req, res);
  } catch (err) {
    console.error('oidc-dev error:', err.message);
    res.writeHead(500); res.end('error');
  }
};
(tls ? createHttpsServer(tls, handler) : createHttpServer(handler))
  .listen(PORT, () => console.log(`OIDC de pruebas en ${ISSUER} (puerto ${PORT}, ${tls ? 'TLS' : 'sin TLS'})`));
