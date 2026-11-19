#!/usr/bin/env node
// Génère assets/data/ciqual.json à partir de la table Ciqual 2025 (Anses, Licence Ouverte 2.0).
//
// Usage :
//   node tool/build_ciqual.mjs                 # télécharge les XML (Zenodo, miroir officiel Anses) puis convertit
//   node tool/build_ciqual.mjs --dir ./xml     # utilise des XML déjà téléchargés (alim_*.xml, compo_*.xml, ...)
//
// Sources : https://doi.org/10.57745/RDMHWY (Recherche Data Gouv) — miroir https://zenodo.org/records/17550133
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile, readdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDataset, decodeXml, parseRecords } from './ciqual_lib.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const VERSION = '2025_11_03';
const BASE_URL = process.env.CIQUAL_BASE_URL ?? 'https://zenodo.org/records/17550133/files';
const FILES = {
  alim: { name: `alim_${VERSION}.xml`, md5: '8e1171d63cee4b6010cfce25dd29243d' },
  groups: { name: `alim_grp_${VERSION}.xml`, md5: 'c31aeea90349c3aab86f98ef5f4f10da' },
  compo: { name: `compo_${VERSION}.xml`, md5: '2da725585946434df320d8041631998b' },
  constants: { name: `const_${VERSION}.xml`, md5: 'd8f2f25fdacb887bc993a6eeaf80f203' },
};
const SOURCE =
  'Anses. 2025. Table de composition nutritionnelle des aliments Ciqual 2025. https://doi.org/10.57745/RDMHWY';
const OUT = path.join(ROOT, 'assets', 'data', 'ciqual.json');

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

async function download(file, cacheDir) {
  const dest = path.join(cacheDir, file.name);
  if (existsSync(dest)) {
    const buf = await readFile(dest);
    if (md5(buf) === file.md5) return buf;
  }
  const url = `${BASE_URL}/${encodeURIComponent(file.name)}?download=1`;
  process.stdout.write(`Téléchargement ${url} ... `);
  const res = await fetch(url, { headers: { 'User-Agent': 'Caillou-data-builder (https://github.com/remigl/caillou)' } });
  if (!res.ok) throw new Error(`HTTP ${res.status} pour ${url}`);
  const buf = Buffer.from(await res.arrayBuffer());
  console.log(`${(buf.length / 1e6).toFixed(1)} Mo`);
  if (md5(buf) !== file.md5) {
    throw new Error(`Somme MD5 inattendue pour ${file.name} (fichier modifié ou corrompu).`);
  }
  await writeFile(dest, buf);
  return buf;
}

const md5 = (buf) => createHash('md5').update(buf).digest('hex');

async function fromDir(dir, file) {
  const prefix = file.name.replace(`_${VERSION}.xml`, '_');
  const names = await readdir(dir);
  const hit = names.find((n) => n.startsWith(prefix) && n.endsWith('.xml') && !(prefix === 'alim_' && n.startsWith('alim_grp')));
  if (!hit) throw new Error(`Fichier ${prefix}*.xml introuvable dans ${dir}`);
  return readFile(path.join(dir, hit));
}

async function main() {
  const dir = arg('--dir');
  const cacheDir = path.join(ROOT, '.ciqual-cache');
  if (!dir) await mkdir(cacheDir, { recursive: true });

  const xml = {};
  for (const [key, file] of Object.entries(FILES)) {
    const buf = dir ? await fromDir(dir, file) : await download(file, cacheDir);
    xml[key] = decodeXml(buf);
  }

  const { dataset, stats } = buildDataset({
    alim: parseRecords(xml.alim, 'ALIM'),
    compo: parseRecords(xml.compo, 'COMPO'),
    constants: parseRecords(xml.constants, 'CONST'),
    groups: parseRecords(xml.groups, 'ALIM_GRP'),
    version: VERSION,
    source: SOURCE,
  });

  console.log('\nCorrespondance des constituants :');
  for (const [k, m] of Object.entries(stats.mapping)) console.log(`  ${k.padEnd(12)} -> ${m.code} ${m.name}`);
  for (const w of stats.warnings) console.warn(`  ⚠ ${w}`);
  console.log(`\nComposition détaillée : ${stats.details.length} constituants`);
  for (const d of stats.details) console.log(`  [${d.g}] ${d.n} (${d.u})`);
  console.log(`\n${stats.foods} aliments, ${stats.withKcal} avec énergie (dont ${stats.energyFallback} via facteur de Jones).`);
  if (stats.unreadable) console.warn(`⚠ ${stats.unreadable} teneurs illisibles ignorées (affichées « non disponible »).`);
  if (stats.foods < 1000) throw new Error('Moins de 1000 aliments : conversion suspecte, arrêt.');

  await mkdir(path.dirname(OUT), { recursive: true });
  await writeFile(OUT, JSON.stringify(dataset));
  console.log(`Écrit : ${path.relative(ROOT, OUT)}`);
}

main().catch((e) => {
  console.error(`\nÉchec : ${e.message}`);
  process.exit(1);
});
