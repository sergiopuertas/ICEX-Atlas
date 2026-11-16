import { deepStrictEqual, ok, rejects, strictEqual, throws } from 'node:assert/strict';
import { EMBEDDING_DIM, MockEmbeddings, MockLlm, parseDraft, toPgVector } from '../_shared/ai.ts';
import { motivo, orientar, validate } from '../orientador/index.ts';
import { fakeDb } from './fake_db.ts';

const cos = (a: number[], b: number[]) => a.reduce((s, x, i) => s + x * b[i], 0);

Deno.test('MockEmbeddings: determinista, normalizado y con similitud semántica básica', async () => {
  const e = new MockEmbeddings();
  const a = await e.embed('Preparar la entrevista de Fase II en Alemania');
  const b = await e.embed('preparar entrevista fase II alemania');
  const c = await e.embed('Distribuidores de vino en México');
  strictEqual(a.length, EMBEDDING_DIM);
  deepStrictEqual(a, await e.embed('Preparar la entrevista de Fase II en Alemania'));
  ok(Math.abs(Math.hypot(...a) - 1) < 1e-9);
  ok(cos(a, b) > 0.6, 'textos parecidos → vectores cercanos');
  ok(cos(a, b) > cos(a, c), 'más cerca de lo parecido que de lo distinto');
  ok(toPgVector(a).startsWith('[') && toPgVector(a).split(',').length === EMBEDDING_DIM);
});

Deno.test('MockLlm: pasos según tema y fase, máximo 4', async () => {
  const d = await new MockLlm().draft({ fase: 'fase_1', pais: 'Alemania', sector: 'Energía',
    consulta: 'Quiero preparar las entrevistas', contexto: { publicaciones: [], perfiles: [] } });
  strictEqual(d.pasos.length, 4);
  ok(d.pasos[0].includes('historias'), 'el tema "entrevista" va primero');
  ok(d.resumen.includes('Alemania'));
});

Deno.test('parseDraft valida el JSON del LLM', () => {
  deepStrictEqual(parseDraft('Claro: {"resumen":"r","pasos":["a","b"]}'), { resumen: 'r', pasos: ['a', 'b'] });
  throws(() => parseDraft('sin json'));
  throws(() => parseDraft('{"resumen":1,"pasos":[]}'));
});

Deno.test('validate: fase obligatoria y consulta por defecto', () => {
  throws(() => validate({ fase: 'fase_9', pais: 'X', sector: 'Y' }));
  throws(() => validate({ fase: 'activo', pais: '', sector: 'Y' }));
  ok(validate({ fase: 'activo', pais: 'Perú', sector: 'Banca', consulta: '' }).consulta.includes('Banca'));
});

Deno.test('motivo menciona cargo, empresa y conocimiento del mercado', () => {
  const m = motivo({ user_id: '1', slug: 's', nombre: 'N', cargo: 'Export Manager', empresa: 'Sener', ciudad: 'Berlín', pais: 'Alemania' },
    { fase: 'activo', pais: 'Alemania', sector: 'Industria', consulta: '' });
  strictEqual(m, 'Export Manager en Sener · Berlín — conoce el mercado de Alemania');
});

Deno.test('orientar: reserva, contexto, LLM y registro; alumni reales del contexto', async () => {
  const { db, calls } = fakeDb({
    orientador_reserve: () => ({ restantes: 9 }),
    orientador_context: () => ({
      perfiles: [{ user_id: 'u1', slug: 'ana-1', nombre: 'Ana', cargo: 'Country Manager', empresa: 'BID', ciudad: 'Berlín', pais: 'Alemania' }],
      publicaciones: [{ post_id: 'p1', extracto: 'Recién llegada a Berlín…' }],
    }),
    orientador_complete: () => null,
  });
  const r = await orientar(db, { fase: 'fase_2', pais: 'Alemania', sector: 'Salud', consulta: 'primer empleo' },
    new MockEmbeddings(), new MockLlm());
  deepStrictEqual(calls.map((c) => c.fn), ['orientador_reserve', 'orientador_context', 'orientador_complete']);
  strictEqual(r.alumni[0].slug, 'ana-1');
  strictEqual(r.restantes, 9);
  ok(r.pasos.length > 0 && r.aviso.includes('fuentes oficiales'));
});

Deno.test('orientar: si el LLM falla, responde con el mock (degradación controlada)', async () => {
  const { db } = fakeDb({
    orientador_reserve: () => ({ restantes: 1 }),
    orientador_context: () => ({ perfiles: [], publicaciones: [] }),
    orientador_complete: () => null,
  });
  const broken = { name: 'roto', draft: () => Promise.reject(new Error('timeout')) };
  const r = await orientar(db, { fase: 'activo', pais: 'Perú', sector: 'Banca', consulta: 'x' }, new MockEmbeddings(), broken);
  strictEqual(r.proveedor, 'roto→mock');
});

Deno.test('orientar: límite diario → 429 rate_limited', async () => {
  const { db } = fakeDb({
    orientador_reserve: () => { throw Object.assign(new Error('Has alcanzado el límite'), { code: 'P0001', hint: 'rate_limited' }); },
  });
  await rejects(orientar(db, { fase: 'activo', pais: 'Perú', sector: 'Banca', consulta: 'x' }, new MockEmbeddings(), new MockLlm()),
    (e: { status?: number; code?: string }) => e.status === 429 && e.code === 'rate_limited');
});
