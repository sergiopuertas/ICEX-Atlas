// Doble de prueba mínimo de SupabaseClient.rpc para tests unitarios de Edge Functions.
import type { Db } from '../_shared/supabase.ts';

export type Handler = (args: Record<string, unknown>) => unknown;

export function fakeDb(handlers: Record<string, Handler>) {
  const calls: { fn: string; args: Record<string, unknown> }[] = [];
  const db = {
    rpc(fn: string, args: Record<string, unknown> = {}) {
      calls.push({ fn, args });
      const h = handlers[fn];
      if (!h) return Promise.resolve({ data: null, error: { code: 'TEST', message: `sin handler ${fn}` } });
      try {
        return Promise.resolve({ data: h(args), error: null });
      } catch (e) {
        const err = e as { code?: string; message?: string; hint?: string };
        return Promise.resolve({ data: null, error: { code: err.code ?? 'XX000', message: err.message, hint: err.hint } });
      }
    },
  };
  return { db: db as unknown as Db, calls };
}
