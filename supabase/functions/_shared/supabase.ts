// Clientes de Supabase para Edge Functions.
// - userClient: actúa con el JWT del socio → RLS y api.* aplican como en la app.
// - serviceClient: service_role (solo dentro de funciones; NUNCA en la app).
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2.119.0';

// deno-lint-ignore no-explicit-any
export type Db = SupabaseClient<any, any, any>;

export function env(name: string, fallback?: string): string {
  const v = Deno.env.get(name) ?? fallback;
  if (v === undefined) throw new Error(`Falta la variable de entorno ${name}`);
  return v;
}

export function serviceClient(schema = 'api'): Db {
  return createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
    db: { schema },
  });
}

export function userClient(req: Request): Db {
  const authorization = req.headers.get('Authorization') ?? '';
  return createClient(env('SUPABASE_URL'), env('SUPABASE_ANON_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
    db: { schema: 'api' },
    global: { headers: { Authorization: authorization } },
  });
}

/** Comprueba que la petición viene con la clave de servicio (invocaciones de pg_cron). */
export function isServiceCall(req: Request): boolean {
  const auth = req.headers.get('Authorization') ?? '';
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  return !!key && auth === `Bearer ${key}`;
}
