import { deepStrictEqual, strictEqual, throws } from 'node:assert/strict';
import { detectImageKind, sanitizeImage, stripJpegMetadata, stripPngMetadata, stripWebpMetadata } from '../_shared/image.ts';

const u8 = (...a: number[]) => new Uint8Array(a);
const seg = (marker: number, payload: number[]) => [0xff, marker, (payload.length + 2) >> 8, (payload.length + 2) & 0xff, ...payload];
const ascii = (s: string) => [...s].map((c) => c.charCodeAt(0));

// JPEG sintético: SOI, APP0 (JFIF), APP1 (Exif con "GPS"), COM, DQT, SOS + datos, EOI
const exif = [...ascii('Exif'), 0, 0, ...ascii('GPS 40.4168N 3.7038W')];
const jpeg = u8(0xff, 0xd8, ...seg(0xe0, ascii('JFIF\0')), ...seg(0xe1, exif), ...seg(0xfe, ascii('comentario')),
  ...seg(0xdb, [0, 1, 2, 3]), ...seg(0xda, [1, 2, 3]), 0x11, 0x22, 0x33, 0xff, 0xd9);

Deno.test('detecta el tipo real por magic bytes, no por extensión', () => {
  strictEqual(detectImageKind(jpeg), 'jpeg');
  strictEqual(detectImageKind(u8(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0)), 'png');
  strictEqual(detectImageKind(u8(...ascii('RIFF'), 0, 0, 0, 0, ...ascii('WEBP'))), 'webp');
  strictEqual(detectImageKind(u8(...ascii('<svg xmlns="'))), null);
  strictEqual(detectImageKind(u8(0x25, 0x50, 0x44, 0x46)), null); // PDF
});

Deno.test('JPEG: elimina EXIF (GPS) y comentarios, conserva el resto', () => {
  const out = stripJpegMetadata(jpeg);
  const text = String.fromCharCode(...out);
  strictEqual(text.includes('GPS'), false);
  strictEqual(text.includes('Exif'), false);
  strictEqual(text.includes('comentario'), false);
  strictEqual(text.includes('JFIF'), true);
  deepStrictEqual([...out.subarray(-4)], [0x22, 0x33, 0xff, 0xd9], 'los datos de imagen tras SOS quedan intactos');
  strictEqual(out.length, jpeg.length - (exif.length + 4) - (ascii('comentario').length + 4));
});

Deno.test('PNG: elimina eXIf y tEXt', () => {
  const chunk = (type: string, data: number[]) => {
    const len = [0, 0, 0, data.length];
    return [...len, ...ascii(type), ...data, 0, 0, 0, 0];
  };
  const png = u8(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, ...chunk('IHDR', [1, 2, 3]),
    ...chunk('eXIf', ascii('GPS')), ...chunk('tEXt', ascii('Author')), ...chunk('IDAT', [9, 9]), ...chunk('IEND', []));
  const out = String.fromCharCode(...stripPngMetadata(png));
  strictEqual(out.includes('eXIf'), false);
  strictEqual(out.includes('tEXt'), false);
  strictEqual(out.includes('IDAT'), true);
  strictEqual(out.includes('IEND'), true);
});

Deno.test('WebP: elimina EXIF/XMP y limpia los flags VP8X', () => {
  const chunk = (type: string, data: number[]) => [...ascii(type), data.length, 0, 0, 0, ...data, ...(data.length % 2 ? [0] : [])];
  const body = [...chunk('VP8X', [0x0c, 0, 0, 0, 0, 0, 0, 0, 0, 0]), ...chunk('VP8 ', [1, 2]), ...chunk('EXIF', ascii('GPS')), ...chunk('XMP ', ascii('x'))];
  const webp = u8(...ascii('RIFF'), (body.length + 4) & 0xff, 0, 0, 0, ...ascii('WEBP'), ...body);
  const out = stripWebpMetadata(webp);
  const s = String.fromCharCode(...out);
  strictEqual(s.includes('EXIF'), false);
  strictEqual(s.includes('XMP '), false);
  strictEqual(out[12 + 8] & 0x0c, 0);
  strictEqual(new DataView(out.buffer).getUint32(4, true), out.length - 8);
});

Deno.test('sanitizeImage rechaza vacíos, grandes y formatos no admitidos', () => {
  throws(() => sanitizeImage(new Uint8Array(), 10), /vacía/);
  throws(() => sanitizeImage(jpeg, 10), /supera/);
  throws(() => sanitizeImage(u8(...ascii('<svg></svg>')), 1000), /no admitido/);
  strictEqual(sanitizeImage(jpeg, 10_000).kind, 'jpeg');
});
