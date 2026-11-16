// Validación y saneado de imágenes (RGPD): tipo REAL por magic bytes, tamaño máximo y
// eliminación de metadatos con ubicación (EXIF/XMP) sin recomprimir la imagen.
// La app además reduce y recomprime antes de subir; esto es la barrera del servidor.

export type ImageKind = 'jpeg' | 'png' | 'webp';
export const MIME: Record<ImageKind, string> = { jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp' };
export const EXT: Record<ImageKind, string> = { jpeg: 'jpg', png: 'png', webp: 'webp' };

export function detectImageKind(b: Uint8Array): ImageKind | null {
  if (b.length >= 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return 'jpeg';
  if (b.length >= 8 && [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].every((v, i) => b[i] === v)) return 'png';
  if (b.length >= 12 && ascii(b, 0, 4) === 'RIFF' && ascii(b, 8, 4) === 'WEBP') return 'webp';
  return null;
}

function ascii(b: Uint8Array, off: number, len: number): string {
  return String.fromCharCode(...b.subarray(off, off + len));
}

/** JPEG: elimina segmentos APP1 (EXIF/XMP, incluye GPS), APP13 (IPTC) y COM. Conserva el resto. */
export function stripJpegMetadata(b: Uint8Array): Uint8Array {
  const out: number[] = [0xff, 0xd8];
  let i = 2;
  while (i + 4 <= b.length) {
    if (b[i] !== 0xff) throw new Error('JPEG corrupto');
    const marker = b[i + 1];
    if (marker === 0xda) { // SOS: el resto son datos de imagen hasta EOI
      for (let k = i; k < b.length; k++) out.push(b[k]);
      return new Uint8Array(out);
    }
    if (marker === 0xd8 || (marker >= 0xd0 && marker <= 0xd7) || marker === 0x01) { // sin longitud
      out.push(0xff, marker);
      i += 2;
      continue;
    }
    const len = (b[i + 2] << 8) | b[i + 3];
    if (len < 2 || i + 2 + len > b.length) throw new Error('JPEG corrupto');
    const drop = marker === 0xe1 || marker === 0xed || marker === 0xfe; // APP1, APP13, COM
    if (!drop) for (let k = i; k < i + 2 + len; k++) out.push(b[k]);
    i += 2 + len;
  }
  throw new Error('JPEG sin datos de imagen');
}

/** PNG: elimina chunks eXIf, tEXt, iTXt y zTXt (pueden llevar ubicación/autor). */
export function stripPngMetadata(b: Uint8Array): Uint8Array {
  const out: Uint8Array[] = [b.subarray(0, 8)];
  let i = 8;
  while (i + 12 <= b.length) {
    const len = new DataView(b.buffer, b.byteOffset + i, 4).getUint32(0);
    const type = ascii(b, i + 4, 4);
    const end = i + 12 + len;
    if (end > b.length) throw new Error('PNG corrupto');
    if (!['eXIf', 'tEXt', 'iTXt', 'zTXt'].includes(type)) out.push(b.subarray(i, end));
    i = end;
    if (type === 'IEND') break;
  }
  return concat(out);
}

/** WebP: elimina chunks EXIF y XMP y desactiva los flags correspondientes en VP8X. */
export function stripWebpMetadata(b: Uint8Array): Uint8Array {
  const chunks: Uint8Array[] = [];
  let i = 12;
  while (i + 8 <= b.length) {
    const type = ascii(b, i, 4);
    const len = new DataView(b.buffer, b.byteOffset + i + 4, 4).getUint32(0, true);
    const end = i + 8 + len + (len % 2);
    if (end > b.length + 1) throw new Error('WebP corrupto');
    if (type !== 'EXIF' && type !== 'XMP ') {
      const c = b.slice(i, Math.min(end, b.length));
      if (type === 'VP8X') c[8] &= ~(0x08 | 0x04); // flags EXIF (bit 3) y XMP (bit 2)
      chunks.push(c);
    }
    i = end;
  }
  const body = concat(chunks);
  const header = new Uint8Array(12);
  header.set(b.subarray(0, 4));
  new DataView(header.buffer).setUint32(4, body.length + 4, true);
  header.set(b.subarray(8, 12), 8);
  return concat([header, body]);
}

export function sanitizeImage(bytes: Uint8Array, maxBytes: number): { kind: ImageKind; data: Uint8Array } {
  if (bytes.length === 0) throw new Error('Imagen vacía');
  if (bytes.length > maxBytes) throw new Error(`La imagen supera ${Math.round(maxBytes / 1024 / 1024)} MB`);
  const kind = detectImageKind(bytes);
  if (!kind) throw new Error('Formato no admitido (solo JPEG, PNG o WebP)');
  const data = kind === 'jpeg' ? stripJpegMetadata(bytes) : kind === 'png' ? stripPngMetadata(bytes) : stripWebpMetadata(bytes);
  return { kind, data };
}

function concat(parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
}
