#!/usr/bin/env node
// Génère assets/data/additives.json (noms et rôles des additifs) depuis la taxonomie Open Food Facts (ODbL).
//   node tool/build_additives.mjs
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildAdditives } from './additives_lib.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const URL = process.env.OFF_ADDITIVES_URL ?? 'https://static.openfoodfacts.org/data/taxonomies/additives.json';
const OUT = path.join(ROOT, 'assets', 'data', 'additives.json');

const res = await fetch(URL, { headers: { 'User-Agent': 'Caillou-data-builder (https://github.com/remigl/caillou)' } });
if (!res.ok) {
  console.error(`Échec : HTTP ${res.status} pour ${URL}`);
  process.exit(1);
}
const table = buildAdditives(await res.json());
const count = Object.keys(table).length;
console.log(`${count} additifs. Exemples :`, table.e330, table.e322, table.e621);
if (count < 200) {
  console.error('Moins de 200 additifs : structure inattendue, arrêt.');
  process.exit(1);
}
await mkdir(path.dirname(OUT), { recursive: true });
await writeFile(OUT, JSON.stringify({ source: 'Open Food Facts, taxonomie des additifs (ODbL)', additives: table }));
console.log(`Écrit : ${path.relative(ROOT, OUT)}`);
