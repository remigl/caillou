// USDA SR Legacy (domaine public, CC0) -> acides aminés, rapprochés des aliments Ciqual par leur nom anglais.
// Format ASCII SR : champs séparés par « ^ », textes entourés de « ~ ».

export const AMINO_ACIDS = [
  // [nom USDA (NutrDesc), libellé français, essentiel]
  ['Histidine', 'Histidine', true],
  ['Isoleucine', 'Isoleucine', true],
  ['Leucine', 'Leucine', true],
  ['Lysine', 'Lysine', true],
  ['Methionine', 'Méthionine', true],
  ['Phenylalanine', 'Phénylalanine', true],
  ['Threonine', 'Thréonine', true],
  ['Tryptophan', 'Tryptophane', true],
  ['Valine', 'Valine', true],
  ['Alanine', 'Alanine', false],
  ['Arginine', 'Arginine', false],
  ['Aspartic acid', 'Acide aspartique', false],
  ['Cystine', 'Cystine', false],
  ['Glutamic acid', 'Acide glutamique', false],
  ['Glycine', 'Glycine', false],
  ['Proline', 'Proline', false],
  ['Serine', 'Sérine', false],
  ['Tyrosine', 'Tyrosine', false],
];

/** Une ligne SR : ~123~^~abc~^1.5 -> ['123', 'abc', '1.5'] */
export function parseSrLine(line) {
  return line.replace(/\r$/, '').split('^').map((f) => f.replace(/^~|~$/g, ''));
}

export function parseSrFile(text) {
  return text.split('\n').filter((l) => l.trim()).map(parseSrLine);
}

const STOP = new Set([
  'and', 'with', 'without', 'or', 'of', 'in', 'the', 'a', 'to', 'from', 'as', 'all', 'ns', 'nfs',
  'pulp', 'peel', 'flesh', 'skin', 'edible', 'part', 'average', 'food', 'prepacked', 'salt', 'added',
  'unenriched', 'enriched', 'mature', 'seed', 'commercial', 'variety', 'type', 'regular', 'plain',
  'unsalted', 'salted', 'unprepared', 'prepared', 'whole', 'fresh', 'solid', 'drained', 'canned',
]);
const STATES = {
  raw: 'raw',
  cooked: 'cooked', boiled: 'cooked', baked: 'cooked', roasted: 'cooked', grilled: 'cooked', broiled: 'cooked',
  fried: 'cooked', steamed: 'cooked', stewed: 'cooked', braised: 'cooked', poached: 'cooked', microwaved: 'cooked',
  'hard-boiled': 'cooked', hardboiled: 'cooked',
  dried: 'dried', dehydrated: 'dried', powder: 'dried',
  frozen: 'frozen',
};

function stem(w) {
  if (w.length > 4 && w.endsWith('ies')) return w.slice(0, -3) + 'y';
  if (w.length > 4 && w.endsWith('oes')) return w.slice(0, -2);
  if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) return w.slice(0, -1);
  return w;
}

/** "Lentils, mature seeds, cooked, boiled" -> { tokens: ['lentil'], states: Set{'cooked'}, head: 'lentil' } */
export function analyzeName(name) {
  const words = name
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/\(.*?\)/g, ' ')
    .split(/[^a-z-]+/)
    .filter(Boolean);
  const tokens = [];
  const states = new Set();
  for (const raw of words) {
    if (STATES[raw]) { states.add(STATES[raw]); continue; }
    for (const part of raw.split('-')) {
      if (!part) continue;
      if (STATES[part]) { states.add(STATES[part]); continue; }
      const s = stem(part);
      if (!STOP.has(s) && !STOP.has(part) && s.length > 1) tokens.push(s);
    }
  }
  return { tokens, states, head: tokens[0] ?? '' };
}

function jaccard(a, b) {
  const A = new Set(a);
  const B = new Set(b);
  let inter = 0;
  for (const x of A) if (B.has(x)) inter++;
  return inter / (A.size + B.size - inter || 1);
}

/** Score de correspondance (0..1) ou 0 si incompatible. */
export function matchScore(ciqualEn, usdaDesc) {
  const c = analyzeName(ciqualEn);
  const u = analyzeName(usdaDesc);
  if (!c.tokens.length || !u.tokens.length) return 0;
  // Le nom principal USDA (premier mot) doit figurer dans le nom Ciqual.
  if (!c.tokens.includes(u.head)) return 0;
  // États incompatibles (cru vs cuit, frais vs séché) : refus.
  for (const s of ['raw', 'cooked', 'dried']) {
    const other = s === 'raw' ? ['cooked', 'dried'] : s === 'cooked' ? ['raw'] : ['raw'];
    if (c.states.has(s) && other.some((o) => u.states.has(o)) && !u.states.has(s)) return 0;
  }
  let score = jaccard(c.tokens, u.tokens);
  if (c.head === u.head) score += 0.15;
  const sameState = [...c.states].some((s) => u.states.has(s));
  if (sameState) score += 0.1;
  return score;
}

/**
 * Construit le jeu de données. foods: [{ndb, desc}], nutrients: [{ndb, nutr, val}], defs: [{nutr, desc}],
 * ciqual: [{c, e, protein}]. Retourne { dataset, stats }.
 */
export function buildAmino({ foods, nutrients, defs, ciqual, minScore = 0.6, minProtein = 2 }) {
  const aminoIndex = new Map();
  AMINO_ACIDS.forEach(([usdaName], i) => {
    const d = defs.find((x) => x.desc.toLowerCase() === usdaName.toLowerCase());
    if (d) aminoIndex.set(String(d.nutr), i);
  });
  if (aminoIndex.size < 15) throw new Error(`Acides aminés introuvables dans NUTR_DEF (${aminoIndex.size}).`);

  const values = new Map();
  for (const n of nutrients) {
    const i = aminoIndex.get(String(n.nutr));
    if (i === undefined) continue;
    const v = Number(n.val);
    if (!Number.isFinite(v)) continue;
    if (!values.has(n.ndb)) values.set(n.ndb, new Array(AMINO_ACIDS.length).fill(null));
    values.get(n.ndb)[i] = v;
  }

  const usda = [];
  const usdaByNdb = new Map();
  const analyzed = [];
  for (const f of foods) {
    const v = values.get(f.ndb);
    if (!v || v.filter((x) => x !== null).length < 9) continue;
    analyzed.push({ f, v, head: analyzeName(f.desc).head });
  }

  const byHead = new Map();
  for (const a of analyzed) {
    if (!byHead.has(a.head)) byHead.set(a.head, []);
    byHead.get(a.head).push(a);
  }

  const mapping = {};
  const samples = [];
  for (const c of ciqual) {
    if (!c.e || !(c.protein >= minProtein)) continue;
    const ct = analyzeName(c.e);
    let best = null;
    let bestScore = 0;
    for (const token of new Set(ct.tokens)) {
      for (const a of byHead.get(token) ?? []) {
        const s = matchScore(c.e, a.f.desc);
        if (s > bestScore || (s === bestScore && best && a.f.desc.length < best.f.desc.length)) {
          bestScore = s;
          best = a;
        }
      }
    }
    if (!best || bestScore < minScore) continue;
    if (!usdaByNdb.has(best.f.ndb)) {
      usdaByNdb.set(best.f.ndb, usda.length);
      usda.push({ n: best.f.ndb, d: best.f.desc, v: best.v });
    }
    mapping[c.c] = usdaByNdb.get(best.f.ndb);
    samples.push(`${c.n ?? c.e}  ->  ${best.f.desc}  (${bestScore.toFixed(2)})`);
  }

  return {
    dataset: {
      source: 'USDA, Agricultural Research Service. FoodData Central — SR Legacy (2018). Domaine public (CC0 1.0).',
      unit: 'g/100 g',
      names: AMINO_ACIDS.map(([, fr]) => fr),
      essential: AMINO_ACIDS.map(([, , e]) => e),
      usda,
      ciqual: mapping,
    },
    stats: { usdaWithAmino: analyzed.length, matched: Object.keys(mapping).length, samples },
  };
}
