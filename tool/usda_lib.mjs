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
  'and', 'with', 'without', 'or', 'of', 'in', 'the', 'a', 'to', 'from', 'as', 'all', 'ns', 'nfs', 'for',
  'pulp', 'peel', 'flesh', 'skin', 'edible', 'part', 'average', 'food', 'prepacked', 'salt', 'added',
  'unenriched', 'enriched', 'mature', 'seed', 'commercial', 'commercially', 'variety', 'type', 'regular', 'plain',
  'unsalted', 'salted', 'unprepared', 'prepared', 'whole', 'fresh', 'solid', 'drained', 'liquid', 'meat',
  // Formules administratives USDA sans rapport avec la nature de l'aliment.
  'separable', 'only', 'trimmed', 'choice', 'select', 'prime', 'broiler', 'fryer', 'class', 'include',
  'distribution', 'program', 'usda', 'refrigerated', 'heated', 'ready', 'eat', 'kernel', 'grade',
]);
const STATES = {
  raw: 'raw',
  cooked: 'cooked', boiled: 'cooked', baked: 'cooked', roasted: 'cooked', grilled: 'cooked', broiled: 'cooked',
  fried: 'cooked', steamed: 'cooked', stewed: 'cooked', braised: 'cooked', poached: 'cooked', microwaved: 'cooked',
  simmered: 'cooked', scrambled: 'cooked', toasted: 'cooked', 'hard-boiled': 'cooked', hardboiled: 'cooked',
  'pan-fried': 'cooked',
  dried: 'dried', dry: 'dried', dehydrated: 'dried', powder: 'dried',
  canned: 'canned', tinned: 'canned',
  frozen: 'frozen',
};
const MAIN_STATES = ['raw', 'cooked', 'dried', 'canned'];

/** Parties ou formes qui changent la composition : présentes des deux côtés ou d'aucun. */
const MUST_MATCH = new Set(['white', 'yolk', 'skin', 'liver', 'heart', 'kidney', 'tongue', 'breast', 'leg', 'wing',
  'thigh', 'drumstick', 'bran', 'germ', 'flour', 'ground', 'juice', 'oil', 'butter', 'powder', 'sprouted', 'smoked', 'cured']);
/** Paires incompatibles : [mots côté Ciqual], [mot côté USDA]. */
const CONFLICTS = [[['green', 'bean'], 'mature'], [['french', 'bean'], 'mature'], [['green', 'pea'], 'mature'], [['white'], 'whole']];
const SYNONYMS = { minced: 'ground', yoghurt: 'yogurt', sprout: 'sprouted' };

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
    .replace(/\b(without|no) skin\b|\bskinless\b/g, ' skinless ')
    .split(/[^a-z-]+/)
    .filter(Boolean);
  const tokens = [];
  const states = new Set();
  const stateWords = new Set();
  for (const raw of words) {
    if (STATES[raw]) { states.add(STATES[raw]); stateWords.add(raw); continue; }
    for (const part of raw.split('-')) {
      if (!part) continue;
      if (STATES[part]) { states.add(STATES[part]); stateWords.add(part); continue; }
      const s = SYNONYMS[stem(part)] ?? stem(part);
      if (!STOP.has(s) && !STOP.has(part) && s.length > 1) tokens.push(s);
    }
  }
  return { tokens, states, stateWords, words: new Set(words.flatMap((w) => w.split('-')).map((w) => SYNONYMS[stem(w)] ?? stem(w))), head: tokens[0] ?? '' };
}

function jaccard(a, b) {
  const A = new Set(a);
  const B = new Set(b);
  let inter = 0;
  for (const x of A) if (B.has(x)) inter++;
  return inter / (A.size + B.size - inter || 1);
}

/**
 * Score de correspondance, 0 si incompatible. Volontairement strict : mieux vaut aucune valeur
 * qu'un aliment différent (cru/cuit, sec/cuit, plat composé...).
 */
export function matchScore(ciqualEn, usdaDesc) {
  const c = analyzeName(ciqualEn);
  const u = analyzeName(usdaDesc);
  if (!c.tokens.length || !u.tokens.length) return 0;
  // Le nom principal USDA (premier mot) doit figurer dans le nom Ciqual.
  if (!c.tokens.includes(u.head)) return 0;
  // Même état principal (cru, cuit, sec, conserve) ; sans état côté Ciqual, pas de sec ni de conserve côté USDA.
  const cs = MAIN_STATES.filter((s) => c.states.has(s));
  const us = MAIN_STATES.filter((s) => u.states.has(s));
  if (cs.length) {
    if (cs.join() !== us.join()) return 0;
  } else if (us.includes('dried') || us.includes('canned')) {
    return 0;
  }
  // Sans état côté Ciqual, pas de cuisson précise côté USDA (« Tofu » ≠ « Tofu, fried »).
  const genericWords = new Set(['raw', 'cooked']);
  if (!cs.length && [...u.stateWords].some((w) => !genericWords.has(w))) return 0;
  for (const p of MUST_MATCH) if (c.words.has(p) !== u.words.has(p)) return 0;
  for (const [cw, uw] of CONFLICTS) {
    if (cw.every((w) => c.words.has(w)) && u.words.has(uw) && !c.words.has(uw)) return 0;
  }
  const C = new Set(c.tokens);
  const U = new Set(u.tokens);
  let inter = 0;
  for (const x of C) if (U.has(x)) inter++;
  const covC = inter / C.size; // part du nom Ciqual expliquée
  const covU = inter / U.size; // part du nom USDA expliquée
  // Règle souple (USDA plus générique, un seul qualificatif Ciqual en plus) seulement si l'état est précisé
  // des deux côtés : « Lentil, green, cooked » ~ « Lentils, cooked », mais pas « Couscous with fish » ~ « Couscous ».
  const accepted = (cs.length > 0 && c.head === u.head && covU === 1 && covC >= 0.5) || (covC >= 0.75 && covU >= 0.6);
  if (!accepted) return 0;
  let score = (covC + covU) / 2;
  if (c.head === u.head) score += 0.15;
  for (const w of c.stateWords) if (u.stateWords.has(w)) score += 0.2; // « hard-boiled » = « hard-boiled »
  // Modes de cuisson précisés des deux côtés mais différents (grillé ≠ bouilli) : refus.
  const generic = new Set(['raw', 'cooked']);
  const cw = [...c.stateWords].filter((w) => !generic.has(w));
  const uw = [...u.stateWords].filter((w) => !generic.has(w));
  if (cw.length && uw.length && !cw.some((w) => uw.includes(w))) return 0;
  return score;
}

const DISH_GROUP = /plat|pizza|sandwich|soupe|dessert|glace|gateau|patisserie|viennoiserie|biscuit|confiserie|sauce|quiche|tarte|entremet|barre|petit-dejeuner|aperitif|feuillete|cremes et specialites|traiteur|salades composees|infantile|tartinable|chocolat/;

/**
 * Construit le jeu de données. foods: [{ndb, desc}], nutrients: [{ndb, nutr, val}], defs: [{nutr, desc}],
 * ciqual: [{c, e, protein}]. Retourne { dataset, stats }.
 */
export function buildAmino({ foods, nutrients, defs, ciqual, minScore = 0.7, minProtein = 2 }) {
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
    // Plats composés, desserts, pâtisseries : la recette fait trop varier la composition.
    if (DISH_GROUP.test((c.g ?? '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase())) continue;
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
