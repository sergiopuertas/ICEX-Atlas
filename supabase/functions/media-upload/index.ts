// media-upload · POST (cuerpo binario de la imagen) con el JWT del socio.
//   ?bucket=avatars|post-media
// Valida el tipo REAL (magic bytes), el tamaño y elimina EXIF/XMP (ubicación) antes de
// guardar en Storage bajo <user_id>/<uuid>.<ext>. Los clientes no pueden subir directamente.
import { handle, HttpError, json, log, rpcError } from '../_shared/http.ts';
import { serviceClient, userClient } from '../_shared/supabase.ts';
import { EXT, MIME, sanitizeImage } from '../_shared/image.ts';

const LIMITS: Record<string, number> = { avatars: 5 * 1024 * 1024, 'post-media': 8 * 1024 * 1024 };

if (import.meta.main) {
  Deno.serve({ port: Number(Deno.env.get("FN_PORT") ?? 8000) }, handle(async (req) => {
    if (req.method !== 'POST') throw new HttpError(405, 'method', 'Usa POST');
    const bucket = new URL(req.url).searchParams.get('bucket') ?? 'post-media';
    if (!(bucket in LIMITS)) throw new HttpError(400, 'invalid', 'Bucket no válido');

    // Membresía activa (y uid) a través de la API con RLS.
    const me = await userClient(req).rpc('me');
    if (me.error) rpcError(me.error);
    const uid = me.data.user_id as string;

    const declared = Number(req.headers.get('content-length') ?? '0');
    if (declared > LIMITS[bucket]) throw new HttpError(413, 'too_large', 'La imagen es demasiado grande');
    const bytes = new Uint8Array(await req.arrayBuffer());
    let clean;
    try {
      clean = sanitizeImage(bytes, LIMITS[bucket]);
    } catch (e) {
      throw new HttpError(415, 'invalid_image', (e as Error).message);
    }
    const path = `${uid}/${crypto.randomUUID()}.${EXT[clean.kind]}`;
    const { error } = await serviceClient().storage.from(bucket).upload(path, clean.data, {
      contentType: MIME[clean.kind], upsert: false, cacheControl: '31536000',
    });
    if (error) throw new HttpError(500, 'storage', 'No se pudo guardar la imagen');
    log('media_upload', { bucket, bytes: clean.data.length, kind: clean.kind });
    return json(req, { bucket, path, content_type: MIME[clean.kind], bytes: clean.data.length }, 201);
  }));
}
