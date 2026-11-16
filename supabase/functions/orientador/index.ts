// orientador · POST { fase, pais, sector, consulta } con el JWT del socio.
// Reserva cupo diario → embedding de la consulta → contexto pgvector (publicaciones y
// perfiles que aceptan ser sugeridos) → borrador del LLM (proveedor intercambiable) →
// respuesta con pasos concretos y alumni sugeridos (siempre reales, nunca inventados por el LLM).
import { handle, HttpError, json, log, rpcError } from '../_shared/http.ts';
import { type Db, userClient } from '../_shared/supabase.ts';
import {
  embeddingsFromEnv, type EmbeddingsProvider, llmFromEnv, type LlmProvider, MockLlm, type OrientadorInput, toPgVector,
} from '../_shared/ai.ts';

const FASES = new Set(['fase_0', 'fase_1', 'fase_2', 'activo']);

export interface OrientadorRequest { fase: string; pais: string; sector: string; consulta: string }

type Perfil = { user_id: string; slug: string; nombre: string; cargo?: string; empresa?: string; ciudad?: string; pais?: string; fase?: string; promocion?: number };

export function validate(body: Partial<OrientadorRequest>): OrientadorRequest {
  const fase = String(body.fase ?? '');
  const pais = String(body.pais ?? '').trim().slice(0, 80);
  const sector = String(body.sector ?? '').trim().slice(0, 80);
  const consulta = String(body.consulta ?? '').trim().slice(0, 2000);
  if (!FASES.has(fase)) throw new HttpError(400, 'invalid', 'Fase no válida');
  if (!pais || !sector) throw new HttpError(400, 'invalid', 'Indica país y sector');
  return { fase, pais, sector, consulta: consulta || `Siguiente paso profesional en ${sector} en ${pais}` };
}

export function motivo(p: Perfil, req: OrientadorRequest): string {
  const partes = [p.cargo && p.empresa ? `${p.cargo} en ${p.empresa}` : p.empresa ?? p.cargo, p.ciudad].filter(Boolean);
  const base = partes.join(' · ');
  return p.pais === req.pais ? `${base} — conoce el mercado de ${req.pais}` : base;
}

export async function orientar(db: Db, req: OrientadorRequest, emb: EmbeddingsProvider, llm: LlmProvider) {
  const id = crypto.randomUUID();
  const reserve = await db.rpc('orientador_reserve', {
    p_id: id, p_fase: req.fase, p_pais: req.pais, p_sector: req.sector, p_consulta: req.consulta,
  });
  if (reserve.error) rpcError(reserve.error);

  const vector = await emb.embed(`${req.consulta}. ${req.sector}. ${req.pais}. ${req.fase}`);
  const ctx = await db.rpc('orientador_context', { p_embedding: toPgVector(vector), p_pais: req.pais, p_sector: req.sector, p_limit: 6 });
  if (ctx.error) rpcError(ctx.error);
  const perfiles = (ctx.data?.perfiles ?? []) as Perfil[];
  const publicaciones = (ctx.data?.publicaciones ?? []) as { post_id: string; extracto: string }[];

  const input: OrientadorInput = { ...req, contexto: { publicaciones, perfiles } };
  let proveedor = llm.name;
  let draft;
  try {
    draft = await llm.draft(input);
  } catch (e) {
    log('orientador_llm_fallback', { provider: llm.name, error: (e as Error).message.slice(0, 80) });
    proveedor = `${llm.name}→mock`;
    draft = await new MockLlm().draft(input);
  }

  const respuesta = {
    id,
    resumen: draft.resumen,
    pasos: draft.pasos,
    alumni: perfiles.slice(0, 3).map((p) => ({
      user_id: p.user_id, slug: p.slug, nombre: p.nombre, fase: p.fase, promocion: p.promocion, motivo: motivo(p, req),
    })),
    publicaciones: publicaciones.slice(0, 3),
    aviso: 'Recomendaciones orientativas generadas con IA. Contrasta trámites, visados y condiciones con fuentes oficiales.',
    restantes: reserve.data?.restantes ?? null,
    proveedor,
  };
  const done = await db.rpc('orientador_complete', { p_id: id, p_respuesta: respuesta, p_proveedor: proveedor });
  if (done.error) rpcError(done.error);
  return respuesta;
}

if (import.meta.main) {
  Deno.serve({ port: Number(Deno.env.get("FN_PORT") ?? 8000) }, handle(async (req) => {
    if (req.method !== 'POST') throw new HttpError(405, 'method', 'Usa POST');
    const body = validate(await req.json().catch(() => ({})));
    const result = await orientar(userClient(req), body, embeddingsFromEnv(), llmFromEnv());
    log('orientador_ok', { provider: result.proveedor, alumni: result.alumni.length });
    return json(req, result);
  }));
}
