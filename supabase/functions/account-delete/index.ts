// account-delete · POST { confirmacion: "BORRAR MI CUENTA" } con el JWT del socio (art. 17 RGPD).
// 1) Borra los ficheros del socio en Storage (avatars y post-media, carpeta <user_id>/).
// 2) Llama a api.delete_my_account, que borra mensajes enviados y el usuario de Auth (cascada).
import { handle, HttpError, json, log, rpcError } from '../_shared/http.ts';
import { serviceClient, userClient } from '../_shared/supabase.ts';

if (import.meta.main) {
  Deno.serve({ port: Number(Deno.env.get("FN_PORT") ?? 8000) }, handle(async (req) => {
    if (req.method !== 'POST') throw new HttpError(405, 'method', 'Usa POST');
    const { confirmacion } = await req.json().catch(() => ({}));
    if (confirmacion !== 'BORRAR MI CUENTA') throw new HttpError(400, 'invalid', 'Confirmación incorrecta');

    const user = userClient(req);
    const me = await user.rpc('me');
    if (me.error) rpcError(me.error);
    const uid = me.data.user_id as string;

    const storage = serviceClient().storage;
    let files = 0;
    for (const bucket of ['avatars', 'post-media']) {
      for (;;) {
        const { data, error } = await storage.from(bucket).list(uid, { limit: 100 });
        if (error) throw new HttpError(500, 'storage', 'No se pudieron listar los ficheros');
        if (!data?.length) break;
        const del = await storage.from(bucket).remove(data.map((f) => `${uid}/${f.name}`));
        if (del.error) throw new HttpError(500, 'storage', 'No se pudieron borrar los ficheros');
        files += data.length;
        if (data.length < 100) break;
      }
    }
    const del = await user.rpc('delete_my_account', { p_confirmacion: confirmacion });
    if (del.error) rpcError(del.error);
    log('account_deleted', { files });
    return json(req, { ok: true, ficheros_borrados: files });
  }));
}
