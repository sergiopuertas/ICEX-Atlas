// Proveedores de IA intercambiables para el Orientador.
//
//   EMBEDDINGS_PROVIDER = mock | supabase-gte-small        (384 dimensiones)
//   LLM_PROVIDER        = mock | openai-compatible | anthropic
//
// En desarrollo y tests: `mock` (determinista, sin red). En producción la elección del
// proveedor (y su tratamiento de datos en la UE) es una PARADA HUMANA (docs/PARADAS_HUMANAS.md).

export const EMBEDDING_DIM = 384;

export interface EmbeddingsProvider {
  readonly name: string;
  embed(text: string): Promise<number[]>;
}

export interface OrientadorInput {
  fase: string;
  pais: string;
  sector: string;
  consulta: string;
  contexto: { publicaciones: { extracto: string }[]; perfiles: { nombre: string; cargo?: string; empresa?: string; ciudad?: string }[] };
}

export interface OrientadorDraft {
  resumen: string;
  pasos: string[];
}

export interface LlmProvider {
  readonly name: string;
  draft(input: OrientadorInput): Promise<OrientadorDraft>;
}

// ------------------------------------------------------------------ mock -------
const STOP = new Set(['de', 'la', 'el', 'en', 'y', 'a', 'que', 'los', 'las', 'un', 'una', 'por', 'con', 'para', 'del',
  'al', 'es', 'mi', 'tu', 'su', 'se', 'lo', 'no', 'me', 'te', 'o', 'the', 'and', 'of', 'to']);

export function normalize(text: string): string[] {
  return text.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')
    .split(/[^a-z0-9ñ]+/).filter((t) => t.length > 2 && !STOP.has(t));
}

function fnv1a(s: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 0x01000193); }
  return h >>> 0;
}

/** Feature hashing de unigramas y bigramas, normalizado L2. Determinista y sin red. */
export class MockEmbeddings implements EmbeddingsProvider {
  readonly name = 'mock';
  embed(text: string): Promise<number[]> {
    const v = new Array(EMBEDDING_DIM).fill(0);
    const toks = normalize(text);
    const feats = [...toks, ...toks.slice(1).map((t, i) => `${toks[i]}_${t}`)];
    for (const f of feats) {
      const h = fnv1a(f);
      v[h % EMBEDDING_DIM] += (h & 0x80000000) ? -1 : 1;
    }
    const n = Math.hypot(...v) || 1;
    return Promise.resolve(v.map((x) => x / n));
  }
}

/** gte-small dentro del propio Edge Runtime de Supabase: los textos no salen de Supabase. */
export class SupabaseGteSmall implements EmbeddingsProvider {
  readonly name = 'supabase-gte-small';
  // deno-lint-ignore no-explicit-any
  #session: any;
  async embed(text: string): Promise<number[]> {
    // deno-lint-ignore no-explicit-any
    const ai = (globalThis as any).Supabase?.ai;
    if (!ai) throw new Error('Supabase.ai no disponible en este runtime');
    this.#session ??= new ai.Session('gte-small');
    return await this.#session.run(text.slice(0, 2000), { mean_pool: true, normalize: true });
  }
}

const PASOS_FASE: Record<string, string[]> = {
  fase_0: [
    'Habla con alumni que hicieron la beca en tus destinos candidatos antes de elegir.',
    'Refuerza idioma y análisis de mercado: son lo primero que se nota en la oficina.',
  ],
  fase_1: [
    'Documenta 3 proyectos concretos de la beca: qué decisión se tomó y qué aportaste.',
    'Empieza a contactar empresas de Fase II con 3 o 4 meses de antelación.',
    'Pide a tu tutor de la oficina una valoración por escrito antes de terminar.',
  ],
  fase_2: [
    'Convierte las prácticas en caso de éxito medible: ventas, mercados abiertos, ahorro.',
    'Pregunta pronto por la posibilidad de incorporación; no esperes al último mes.',
    'Activa la red: avisa en el feed de que buscas tu siguiente paso y en qué mercado.',
  ],
  activo: [
    'Identifica qué experiencia transferible tienes y cuéntala en el idioma del nuevo sector.',
    'Ofrece mentoría a promociones recientes: amplía tu red y tu visibilidad.',
    'Revisa los clubs locales de tu destino para conocer a quien ya está en el mercado.',
  ],
};

const PASOS_TEMA: [RegExp, string][] = [
  [/entrevista/, 'Prepara 3 historias con estructura situación–análisis–resultado y ensáyalas con un alumni del sector.'],
  [/empleo|trabajo|puesto|oferta/, 'Publica en el feed qué buscas, en qué mercado y desde cuándo: la red responde mejor a peticiones concretas.'],
  [/cambi.*sector|sector/, 'Busca un puesto puente (desarrollo de negocio, export manager) que valore tu sector actual y te acerque al nuevo.'],
  [/destino|beca|elegir/, 'Compara destinos con tres criterios: sectores de la oficina, idioma y salidas de alumni que estuvieron allí.'],
  [/salario|sueldo|negoci/, 'Pregunta rangos salariales a alumni del mismo país antes de negociar; varían mucho por mercado.'],
  [/empren/, 'Habla con alumni que hayan emprendido y valida tu idea con clientes del mercado objetivo.'],
];

export class MockLlm implements LlmProvider {
  readonly name = 'mock';
  draft(input: OrientadorInput): Promise<OrientadorDraft> {
    const q = normalize(input.consulta).join(' ');
    const tema = PASOS_TEMA.filter(([re]) => re.test(q)).map(([, p]) => p);
    const pasos = [...tema, ...(PASOS_FASE[input.fase] ?? PASOS_FASE.activo)];
    pasos.push(`Únete al club local más cercano en ${input.pais} y pide una presentación a dos personas del sector.`);
    const fase = input.fase === 'activo' ? 'en el mercado laboral' : 'dentro del programa';
    return Promise.resolve({
      resumen: `Estás ${fase} y te interesa ${input.sector.toLowerCase()} en ${input.pais}. Estos son tus próximos pasos.`,
      pasos: [...new Set(pasos)].slice(0, 4),
    });
  }
}

// ------------------------------------------------------- proveedores reales ---
const SYSTEM_PROMPT = `Eres el Orientador de ICEX Alumni. Das 3-4 pasos concretos, accionables y breves (máx. 30
palabras cada uno) en español de España para becarios y alumni ICEX según su fase (Fase 0, I, II o Activo), país y
sector. No inventes datos legales, salariales ni de visados: remite a fuentes oficiales. No menciones a personas.
Responde SOLO con JSON: {"resumen": string, "pasos": string[]}.`;

function userPrompt(i: OrientadorInput): string {
  const ctx = i.contexto.publicaciones.slice(0, 5).map((p, n) => `${n + 1}. ${p.extracto}`).join('\n');
  return `Fase: ${i.fase}\nPaís de interés: ${i.pais}\nSector: ${i.sector}\nConsulta: ${i.consulta}\n\n`
    + `Experiencias de la comunidad (pueden ayudar):\n${ctx || '(sin resultados)'}`;
}

export function parseDraft(text: string): OrientadorDraft {
  const m = text.match(/\{[\s\S]*\}/);
  if (!m) throw new Error('Respuesta sin JSON');
  const d = JSON.parse(m[0]);
  if (typeof d.resumen !== 'string' || !Array.isArray(d.pasos) || d.pasos.some((p: unknown) => typeof p !== 'string')) {
    throw new Error('JSON con formato inesperado');
  }
  return { resumen: d.resumen.slice(0, 400), pasos: d.pasos.slice(0, 4).map((p: string) => p.slice(0, 300)) };
}

/** Cualquier API compatible con /v1/chat/completions (p. ej. Mistral La Plateforme, alojada en la UE). */
export class OpenAiCompatibleLlm implements LlmProvider {
  readonly name: string;
  constructor(private baseUrl: string, private apiKey: string, private model: string) {
    this.name = `openai-compatible:${model}`;
  }
  async draft(input: OrientadorInput): Promise<OrientadorDraft> {
    const r = await fetch(`${this.baseUrl.replace(/\/$/, '')}/chat/completions`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${this.apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: this.model, temperature: 0.3, max_tokens: 600,
        response_format: { type: 'json_object' },
        messages: [{ role: 'system', content: SYSTEM_PROMPT }, { role: 'user', content: userPrompt(input) }],
      }),
      signal: AbortSignal.timeout(25_000),
    });
    if (!r.ok) throw new Error(`LLM HTTP ${r.status}`);
    const body = await r.json();
    return parseDraft(body.choices?.[0]?.message?.content ?? '');
  }
}

export class AnthropicLlm implements LlmProvider {
  readonly name: string;
  constructor(private apiKey: string, private model: string, private baseUrl = 'https://api.anthropic.com') {
    this.name = `anthropic:${model}`;
  }
  async draft(input: OrientadorInput): Promise<OrientadorDraft> {
    const r = await fetch(`${this.baseUrl.replace(/\/$/, '')}/v1/messages`, {
      method: 'POST',
      headers: { 'x-api-key': this.apiKey, 'anthropic-version': '2023-06-01', 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: this.model, max_tokens: 600, temperature: 0.3, system: SYSTEM_PROMPT,
        messages: [{ role: 'user', content: userPrompt(input) }],
      }),
      signal: AbortSignal.timeout(25_000),
    });
    if (!r.ok) throw new Error(`LLM HTTP ${r.status}`);
    const body = await r.json();
    return parseDraft(body.content?.find((c: { type: string }) => c.type === 'text')?.text ?? '');
  }
}

export function embeddingsFromEnv(): EmbeddingsProvider {
  return (Deno.env.get('EMBEDDINGS_PROVIDER') ?? 'mock') === 'supabase-gte-small' ? new SupabaseGteSmall() : new MockEmbeddings();
}

export function llmFromEnv(): LlmProvider {
  const p = Deno.env.get('LLM_PROVIDER') ?? 'mock';
  if (p === 'openai-compatible') {
    return new OpenAiCompatibleLlm(Deno.env.get('LLM_BASE_URL') ?? '', Deno.env.get('LLM_API_KEY') ?? '', Deno.env.get('LLM_MODEL') ?? '');
  }
  if (p === 'anthropic') {
    return new AnthropicLlm(Deno.env.get('LLM_API_KEY') ?? '', Deno.env.get('LLM_MODEL') ?? '', Deno.env.get('LLM_BASE_URL') ?? undefined);
  }
  return new MockLlm();
}

export function toPgVector(v: number[]): string {
  return `[${v.map((x) => (Math.round(x * 1e6) / 1e6).toString()).join(',')}]`;
}
