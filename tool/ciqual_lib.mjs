// Fonctions pures de conversion de la table Ciqual (XML Anses) vers l'asset JSON de l'app.
// Aucune dépendance : Node >= 20.
//
// Format des fichiers XML Ciqual (2020 et 2025) :
//   <TABLE>
//     <ALIM> <alim_code> 13000 </alim_code> <alim_nom_fr> ... </alim_nom_fr> ... </ALIM>
//     <COMPO> <alim_code/> <const_code/> <teneur> 0,2 </teneur> ... </COMPO>
//     <CONST> <const_code/> <const_nom_fr> Lipides (g/100 g) </const_nom_fr> ... </CONST>
//     <ALIM_GRP> <alim_grp_code/> <alim_grp_nom_fr/> <alim_ssgrp_code/> ... </ALIM_GRP>
//   </TABLE>
// Le parseur est volontairement tolérant (casse des balises, espaces, entités XML).

/** Ordre des nutriments dans le tableau `v` de chaque aliment du JSON. */
export const NUTRIENT_KEYS = [
  'kcal', 'kj', 'fat', 'satFat', 'carbs', 'sugars', 'fiber', 'proteins', 'salt',
];

/** Décode un buffer XML selon l'encodage déclaré (UTF-8 en 2025, windows-1252 en 2020). */
export function decodeXml(buffer) {
  const head = Buffer.from(buffer.subarray(0, 200)).toString('latin1');
  const m = head.match(/encoding\s*=\s*["']([^"']+)["']/i);
  const enc = (m ? m[1] : 'utf-8').toLowerCase();
  return new TextDecoder(enc === 'iso-8859-1' ? 'latin1' : enc).decode(buffer);
}

function decodeEntities(s) {
  return s
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(parseInt(d, 10)))
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');
}

/** Extrait les enregistrements <TAG>...</TAG> sous forme d'objets {champ_en_minuscules: valeur}. */
export function parseRecords(xml, tag) {
  const out = [];
  const recordRe = new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`, 'gi');
  const fieldRe = /<([A-Za-z0-9_]+)(?:\s[^>]*)?>([\s\S]*?)<\/\1>/g;
  for (const rec of xml.matchAll(recordRe)) {
    const obj = {};
    for (const f of rec[1].matchAll(fieldRe)) {
      obj[f[1].toLowerCase()] = decodeEntities(f[2]).trim();
    }
    out.push(obj);
  }
  return out;
}

export function normalize(s) {
  return s
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Valeur Ciqual -> valeur JSON.
 *   "0,2" -> 0.2 ; "-" ou "" -> null (donnée absente) ; "traces" -> "traces" ;
 *   "< 0,5" -> "<0.5" (inférieur à la limite de quantification).
 * Retourne undefined si la valeur est illisible (comptée comme anomalie).
 */
export function parseTeneur(raw) {
  if (raw == null) return null;
  const s = String(raw).trim().replace(/ /g, ' ');
  if (s === '' || s === '-' || s === '--') return null;
  if (/^traces?$/i.test(s)) return 'traces';
  const lt = s.match(/^<\s*([0-9]+(?:[.,][0-9]+)?)$/);
  if (lt) return `<${Number(lt[1].replace(',', '.'))}`;
  const n = s.replace(',', '.');
  if (/^-?[0-9]+(?:\.[0-9]+)?$/.test(n)) return Number(n);
  return undefined;
}

/**
 * Associe nos clés de nutriments aux codes constituants Ciqual, par leur nom
 * (plus robuste qu'une liste de codes figée si l'Anses renumérote).
 */
const MATCHERS = {
  kj: (n) => n.includes('energie') && n.includes('1169/2011') && n.includes('kj'),
  kcal: (n) => n.includes('energie') && n.includes('1169/2011') && n.includes('kcal'),
  kjJones: (n) => n.includes('energie') && n.includes('jones') && n.includes('avec fibres') && n.includes('kj'),
  kcalJones: (n) => n.includes('energie') && n.includes('jones') && n.includes('avec fibres') && n.includes('kcal'),
  proteins: (n) => n.startsWith('proteines') && n.includes('jones'),
  proteins625: (n) => n.startsWith('proteines') && (n.includes('6.25') || n.includes('6,25')),
  carbs: (n) => n.startsWith('glucides'),
  sugars: (n) => n.startsWith('sucres'),
  fiber: (n) => n.startsWith('fibres alimentaires'),
  fat: (n) => n.startsWith('lipides'),
  satFat: (n) => n.startsWith('ag satures'),
  salt: (n) => n.startsWith('sel chlorure de sodium'),
};
const REQUIRED = ['kj', 'kcal', 'proteins', 'carbs', 'sugars', 'fiber', 'fat', 'satFat', 'salt'];

export function mapConstituents(constRecords) {
  const mapping = {};
  const warnings = [];
  for (const [key, test] of Object.entries(MATCHERS)) {
    const hits = constRecords.filter((c) => c.const_nom_fr && test(normalize(c.const_nom_fr)));
    if (hits.length > 1) {
      warnings.push(`${key}: ${hits.length} constituants correspondent, le premier est retenu (${hits.map((h) => h.const_code).join(', ')})`);
    }
    if (hits.length > 0) mapping[key] = { code: hits[0].const_code, name: hits[0].const_nom_fr };
  }
  const missing = REQUIRED.filter((k) => !mapping[k]);
  if (missing.length) {
    throw new Error(`Constituants Ciqual introuvables : ${missing.join(', ')}. Le format a peut-être changé.`);
  }
  return { mapping, warnings };
}


/** Format de l'asset : 2 = valeurs principales + composition détaillée. */
export const FORMAT_VERSION = 2;

/** "Calcium (mg/100 g)" -> { label: "Calcium", unit: "mg" }. */
export function splitUnit(name) {
  const m = name.match(/\(\s*([^()]*?)\s*\/\s*100\s*g\s*\)\s*$/i);
  const unit = m ? m[1].replace('ug', 'µg') : '';
  const label = (m ? name.slice(0, m.index) : name).trim().replace(/[,\s]+$/, '');
  return { label, unit };
}

const FRIENDLY = [
  [/^AG monoinsatur/i, 'Acides gras monoinsaturés'],
  [/^AG polyinsatur/i, 'Acides gras polyinsaturés'],
  [/^AG satur/i, 'Acides gras saturés'],
  [/^AG 18:2.*linol[ée]ique/i, 'Oméga-6 : acide linoléique'],
  [/^AG 18:3.*alpha-linol[ée]nique/i, 'Oméga-3 : acide alpha-linolénique (ALA)'],
  [/^AG 20:4.*arachidonique/i, 'Oméga-6 : acide arachidonique'],
  [/^AG 20:5.*EPA/i, 'Oméga-3 : EPA'],
  [/^AG 22:6.*DHA/i, 'Oméga-3 : DHA'],
  [/^AG 18:1.*ol[ée]ique/i, 'Oméga-9 : acide oléique'],
];

export function friendlyLabel(label) {
  for (const [re, out] of FRIENDLY) if (re.test(label)) return out;
  return label.replace(/^AG /, 'Acide gras ');
}

const MINERALS = ['sodium', 'calcium', 'chlorure', 'cuivre', 'fer', 'iode', 'magnesium', 'manganese', 'phosphore', 'potassium', 'selenium', 'zinc'];

export function detailGroup(label) {
  const n = normalize(label);
  if (/^(vitamine|retinol|beta-carot|beta carot|caroten)/.test(n)) return 'Vitamines';
  if (MINERALS.some((m) => n === m || n.startsWith(m + ' '))) return 'Minéraux et oligo-éléments';
  if (/^(ag |acide gras|acides gras|omega|cholest)/.test(n)) return 'Lipides';
  if (/^(amidon|fructose|galactose|glucose|lactose|maltose|saccharose|polyols|fibres)/.test(n)) return 'Glucides';
  return 'Autres';
}

const GROUP_ORDER = ['Glucides', 'Lipides', 'Minéraux et oligo-éléments', 'Vitamines', 'Autres'];

/** Construit l'objet JSON final à partir des enregistrements parsés. */
export function buildDataset({ alim, compo, constants, groups, version, source }) {
  const { mapping, warnings } = mapConstituents(constants);
  const codeToKey = new Map();
  for (const [key, m] of Object.entries(mapping)) codeToKey.set(String(m.code), key);

  // Composition détaillée : tous les autres constituants (vitamines, minéraux, acides gras...).
  const usedCodes = new Set(codeToKey.keys());
  const details = constants
    .filter((c) => c.const_code && c.const_nom_fr && !usedCodes.has(String(c.const_code)))
    .map((c) => {
      const { label, unit } = splitUnit(c.const_nom_fr);
      const nice = friendlyLabel(label);
      return { code: String(c.const_code), n: nice, u: unit, g: detailGroup(nice) };
    })
    .filter((d) => d.u && !/^energie/i.test(normalize(d.n)))
    .sort((a, b) => GROUP_ORDER.indexOf(a.g) - GROUP_ORDER.indexOf(b.g));
  const detailIndex = new Map(details.map((d, i) => [d.code, i]));

  const values = new Map(); // alim_code -> {key: value}
  const detailValues = new Map(); // alim_code -> [index, valeur, index, valeur...]
  let unreadable = 0;
  for (const c of compo) {
    const code = String(c.alim_code);
    const key = codeToKey.get(String(c.const_code));
    const di = detailIndex.get(String(c.const_code));
    if (!key && di === undefined) continue;
    const v = parseTeneur(c.teneur);
    if (v === undefined) { unreadable++; continue; }
    if (key) {
      if (!values.has(code)) values.set(code, {});
      values.get(code)[key] = v;
    } else if (v !== null) {
      if (!detailValues.has(code)) detailValues.set(code, []);
      detailValues.get(code).push(di, v);
    }
  }

  const subgroupNames = new Map();
  for (const g of groups) {
    if (g.alim_ssgrp_code && g.alim_ssgrp_nom_fr) subgroupNames.set(String(g.alim_ssgrp_code), g.alim_ssgrp_nom_fr);
  }

  const isNum = (x) => typeof x === 'number';
  let energyFallback = 0;
  let withKcal = 0;
  const foods = [];
  for (const a of alim) {
    if (!a.alim_code || !a.alim_nom_fr) continue;
    const v = values.get(String(a.alim_code)) ?? {};
    const out = {};
    for (const k of NUTRIENT_KEYS) out[k] = v[k] ?? null;
    // Protéines : facteur de Jones (référence Ciqual), sinon N x 6,25.
    if (out.proteins == null && v.proteins625 != null) out.proteins = v.proteins625;
    // Énergie : règlement UE 1169/2011 ; à défaut, la valeur Ciqual « N x facteur de Jones, avec fibres ».
    // Ce n'est jamais une valeur inventée : c'est un autre calcul publié par l'Anses, signalé dans l'app.
    let ef = 0;
    if (!isNum(out.kcal) && isNum(v.kcalJones)) { out.kcal = v.kcalJones; out.kj = isNum(v.kjJones) ? v.kjJones : out.kj; ef = 1; }
    if (ef) energyFallback++;
    if (isNum(out.kcal)) withKcal++;
    const food = {
      c: Number(a.alim_code),
      n: a.alim_nom_fr,
      v: NUTRIENT_KEYS.map((k) => out[k]),
    };
    if (a.alim_nom_eng) food.e = a.alim_nom_eng;
    const sg = subgroupNames.get(String(a.alim_ssgrp_code));
    if (sg) food.g = sg;
    if (ef) food.ef = 1;
    const d = detailValues.get(String(a.alim_code));
    if (d && d.length) food.d = d;
    foods.push(food);
  }
  foods.sort((x, y) => x.n.localeCompare(y.n, 'fr'));

  return {
    dataset: {
      source,
      licence: 'Licence Ouverte / Open Licence 2.0 (Etalab)',
      version,
      basis: '100 g de partie comestible',
      formatVersion: FORMAT_VERSION,
      nutrients: NUTRIENT_KEYS,
      details: details.map(({ n, u, g }) => ({ n, u, g })),
      foods,
    },
    stats: { foods: foods.length, withKcal, energyFallback, unreadable, mapping, warnings, details },
  };
}
