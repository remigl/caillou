// Conversion de la taxonomie des additifs Open Food Facts (ODbL) en table compacte :
//   { "e330": ["Acide citrique", "Acidifiant, correcteur d'acidité"], ... }
// Structure attendue (défensive) : { "en:e330": { "name": { "fr": "...", "en": "..." },
//   "additives_classes": { "en": "en:acid, en:acidity-regulator" } }, ... }

const CLASSES_FR = {
  'acid': 'acidifiant',
  'acidity-regulator': "correcteur d'acidité",
  'anti-caking-agent': 'antiagglomérant',
  'anti-foaming-agent': 'antimoussant',
  'antioxidant': 'antioxydant',
  'bulking-agent': 'agent de charge',
  'carrier': 'support',
  'colour': 'colorant',
  'colour-retention-agent': 'stabilisateur de couleur',
  'emulsifier': 'émulsifiant',
  'emulsifying-salts': 'sel de fonte',
  'firming-agent': 'affermissant',
  'flavour-enhancer': 'exhausteur de goût',
  'flour-treatment-agent': 'agent de traitement de la farine',
  'foaming-agent': 'moussant',
  'gelling-agent': 'gélifiant',
  'glazing-agent': "agent d'enrobage",
  'humectant': 'humectant',
  'modified-starch': 'amidon modifié',
  'packaging-gas': "gaz d'emballage",
  'preservative': 'conservateur',
  'propellent-gas': 'gaz propulseur',
  'raising-agent': 'poudre à lever',
  'sequestrant': 'séquestrant',
  'stabiliser': 'stabilisant',
  'sweetener': 'édulcorant',
  'thickener': 'épaississant',
};

function pickLang(obj, langs = ['fr', 'en']) {
  if (!obj || typeof obj !== 'object') return undefined;
  for (const l of langs) if (typeof obj[l] === 'string' && obj[l].trim()) return obj[l].trim();
  return undefined;
}

export function buildAdditives(taxonomy) {
  const out = {};
  for (const [id, entry] of Object.entries(taxonomy ?? {})) {
    const m = id.match(/^[a-z]{2}:(e\d{3,4}[a-z]?(?:\([ivx]+\))?)$/i);
    if (!m) continue;
    const code = m[1].toLowerCase();
    let name = pickLang(entry?.name);
    if (!name) continue;
    // "E330 - Acide citrique" -> "Acide citrique"
    name = name.replace(/^e\d+[a-z]?(\([ivx]+\))?\s*[-–:]\s*/i, '').trim();
    const classesRaw = pickLang(entry?.additives_classes, ['en']) ?? '';
    const classes = classesRaw
      .split(',')
      .map((c) => c.trim().replace(/^[a-z]{2}:/, ''))
      .map((c) => CLASSES_FR[c])
      .filter(Boolean);
    const role = classes.length ? classes[0][0].toUpperCase() + classes.join(', ').slice(1) : '';
    out[code] = role ? [name, role] : [name];
  }
  return out;
}
