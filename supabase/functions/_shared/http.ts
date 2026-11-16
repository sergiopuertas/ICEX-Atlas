// Utilidades HTTP comunes: CORS (panel admin web), respuestas JSON y logs sin datos personales.

const ALLOWED_ORIGINS = (Deno.env.get('ADMIN_ALLOWED_ORIGINS') ?? 'http://localhost:8080,http://127.0.0.1:8080')
  .split(',').map((s) => s.trim()).filter(Boolean);

export function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get('Origin') ?? '';
  const allow = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0] ?? '';
  return {
    'Access-Control-Allow-Origin': allow,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-file-name',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    Vary: 'Origin',
  };
}

export function json(req: Request, body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...corsHeaders(req) },
  });
}

export function preflight(req: Request): Response | null {
  return req.method === 'OPTIONS' ? new Response('ok', { headers: corsHeaders(req) }) : null;
}

export class HttpError extends Error {
  constructor(public status: number, public code: string, message: string) {
    super(message);
  }
}

/** Log estructurado. Nunca incluir nombres, emails, textos de mensajes ni tokens (RGPD). */
export function log(event: string, data: Record<string, string | number | boolean | null> = {}): void {
  console.log(JSON.stringify({ event, ...data, ts: new Date().toISOString() }));
}

export function handle(fn: (req: Request) => Promise<Response>) {
  return async (req: Request): Promise<Response> => {
    const pre = preflight(req);
    if (pre) return pre;
    try {
      return await fn(req);
    } catch (e) {
      if (e instanceof HttpError) return json(req, { error: e.code, message: e.message }, e.status);
      log('unhandled_error', { name: (e as Error).name, message: (e as Error).message.slice(0, 120) });
      return json(req, { error: 'internal', message: 'Error interno' }, 500);
    }
  };
}

/** Traduce errores de PostgREST/RPC a HttpError con códigos estables para la app. */
export function rpcError(err: { code?: string; message?: string; hint?: string } | null): never {
  const code = err?.code ?? '';
  if (code === '42501') throw new HttpError(403, 'forbidden', err?.message ?? 'Acceso denegado');
  if (code === 'P0002') throw new HttpError(404, 'not_found', err?.message ?? 'No encontrado');
  if (code === 'P0001' && err?.hint === 'rate_limited') throw new HttpError(429, 'rate_limited', err?.message ?? 'Límite alcanzado');
  if (code === 'P0001') throw new HttpError(409, 'unavailable', err?.message ?? 'No disponible');
  if (code === '22023') throw new HttpError(400, 'invalid', err?.message ?? 'Petición no válida');
  throw new HttpError(500, 'db_error', 'Error de base de datos');
}
