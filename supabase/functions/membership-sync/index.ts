// membership-sync · tarea Cron diaria (service_role).
// Pregunta a la web WordPress de ICEX Alumni qué socios siguen activos y revoca el acceso
// (y las sesiones) de quienes se han dado de baja. Contrato del endpoint: wordpress/README.md
//   POST {WP_BASE_URL}/wp-json/icex-alumni/v1/memberships   { "subjects": ["sub1", ...] }
//   Authorization: Bearer {WP_SYNC_TOKEN}
//   → { "memberships": { "sub1": "active" | "inactive" | "unknown" } }
// Por seguridad, "unknown" NO revoca (evita bajas masivas por un fallo del endpoint).
import { handle, HttpError, json, log } from '../_shared/http.ts';
import { type Db, env, isServiceCall, serviceClient } from '../_shared/supabase.ts';

export type Lookup = (subjects: string[]) => Promise<Record<string, 'active' | 'inactive' | 'unknown'>>;

export function wordpressLookup(baseUrl: string, token: string): Lookup {
  return async (subjects) => {
    const r = await fetch(`${baseUrl.replace(/\/$/, '')}/wp-json/icex-alumni/v1/memberships`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ subjects }),
      signal: AbortSignal.timeout(20_000),
    });
    if (!r.ok) throw new Error(`WordPress HTTP ${r.status}`);
    return (await r.json()).memberships ?? {};
  };
}

export async function sync(db: Db, lookup: Lookup, maxRevokeRatio = 0.05) {
  let after: string | null = null;
  let checked = 0;
  const toRevoke: string[] = [];
  for (;;) {
    const { data, error } = await db.rpc('svc_member_subjects', { p_after: after, p_limit: 200 });
    if (error) throw new Error(`svc_member_subjects: ${error.code}`);
    const page = (data ?? []) as { user_id: string; wp_subject: string }[];
    if (!page.length) break;
    const status = await lookup(page.map((p) => p.wp_subject));
    for (const p of page) if (status[p.wp_subject] === 'inactive') toRevoke.push(p.user_id);
    checked += page.length;
    after = page[page.length - 1].user_id;
  }
  // Freno de seguridad: una caída o error del endpoint no debe dar de baja a media comunidad.
  if (checked > 20 && toRevoke.length / checked > maxRevokeRatio) {
    log('membership_sync_aborted', { checked, would_revoke: toRevoke.length });
    return { checked, revoked: 0, aborted: true };
  }
  for (const uid of toRevoke) {
    const { error } = await db.rpc('svc_revoke_member', { p_user: uid, p_reason: 'baja_wordpress' });
    if (error) throw new Error(`svc_revoke_member: ${error.code}`);
  }
  return { checked, revoked: toRevoke.length, aborted: false };
}

if (import.meta.main) {
  Deno.serve({ port: Number(Deno.env.get("FN_PORT") ?? 8000) }, handle(async (req) => {
    if (!isServiceCall(req)) throw new HttpError(401, 'unauthorized', 'Solo servicio');
    const result = await sync(serviceClient(), wordpressLookup(env('WP_BASE_URL'), env('WP_SYNC_TOKEN')),
      Number(Deno.env.get('MEMBERSHIP_MAX_REVOKE_RATIO') ?? '0.05'));
    log('membership_sync', result);
    return json(req, result);
  }));
}
