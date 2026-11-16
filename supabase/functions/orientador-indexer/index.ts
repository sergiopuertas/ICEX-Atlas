// orientador-indexer · invocada por pg_cron cada minuto (service_role).
// Consume la cola `embeddings` (posts y perfiles creados/modificados) y actualiza
// orientador.documents con el embedding (pgvector). Respeta el consentimiento:
// si el perfil/post ya no debe sugerirse, source_text no devuelve nada y se borra.
import { handle, HttpError, json, log } from '../_shared/http.ts';
import { type Db, isServiceCall, serviceClient } from '../_shared/supabase.ts';
import { embeddingsFromEnv, type EmbeddingsProvider, toPgVector } from '../_shared/ai.ts';

type QueueMsg = { msg_id: number; message: { source_tipo: 'post' | 'perfil' | 'guia'; source_id: string } };

export async function indexBatch(db: Db, emb: EmbeddingsProvider, batch = 100) {
  const { data, error } = await db.rpc('svc_queue_read', { p_queue: 'embeddings', p_qty: batch, p_vt: 300 });
  if (error) throw new Error(`svc_queue_read: ${error.code}`);
  const msgs = (data ?? []) as QueueMsg[];
  const seen = new Set<string>();
  let indexed = 0, removed = 0;
  for (const m of msgs) {
    const key = `${m.message.source_tipo}:${m.message.source_id}`;
    if (seen.has(key)) continue;
    seen.add(key);
    const src = await db.rpc('svc_index_source', { p_tipo: m.message.source_tipo, p_id: m.message.source_id });
    if (src.error) throw new Error(`svc_index_source: ${src.error.code}`);
    if (!src.data?.contenido) {
      await db.rpc('svc_delete_document', { p_tipo: m.message.source_tipo, p_id: m.message.source_id });
      removed++;
      continue;
    }
    const vec = await emb.embed(src.data.contenido);
    const up = await db.rpc('svc_upsert_embedding', { p_tipo: m.message.source_tipo, p_id: m.message.source_id, p_embedding: toPgVector(vec) });
    if (up.error) throw new Error(`svc_upsert_embedding: ${up.error.code}`);
    indexed++;
  }
  if (msgs.length) await db.rpc('svc_queue_ack', { p_queue: 'embeddings', p_ids: msgs.map((m) => m.msg_id) });
  return { leidos: msgs.length, indexados: indexed, eliminados: removed, proveedor: emb.name };
}

if (import.meta.main) {
  Deno.serve({ port: Number(Deno.env.get("FN_PORT") ?? 8000) }, handle(async (req) => {
    if (!isServiceCall(req)) throw new HttpError(401, 'unauthorized', 'Solo servicio');
    const db = serviceClient();
    const emb = embeddingsFromEnv();
    const total = { leidos: 0, indexados: 0, eliminados: 0, proveedor: emb.name };
    // Varias tandas por invocación (hasta ~40 s) para vaciar la cola tras cargas masivas.
    const until = Date.now() + 40_000;
    while (Date.now() < until) {
      const r = await indexBatch(db, emb);
      total.leidos += r.leidos; total.indexados += r.indexados; total.eliminados += r.eliminados;
      if (r.leidos === 0) break;
    }
    log('orientador_index', total);
    return json(req, total);
  }));
}
