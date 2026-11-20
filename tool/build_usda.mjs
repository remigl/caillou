#!/usr/bin/env node
// Génère assets/data/amino.json : acides aminés USDA SR Legacy (domaine public) rapprochés des aliments Ciqual.
//   node tool/build_usda.mjs              # télécharge SR-Leg_ASC.zip (data.gov / figshare) puis convertit
//   node tool/build_usda.mjs --dir ./sr   # utilise FOOD_DES.txt, NUT_DATA.txt, NUTR_DEF.txt déjà extraits
// Nécessite assets/data/ciqual.json (tool/build_ciqual.mjs) et la commande « unzip » pour le téléchargement.
import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildAmino, parseSrFile } from './usda_lib.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const URL = process.env.USDA_SR_URL ?? 'https://ndownloader.figshare.com/files/43633731'; // SR-Leg_ASC.zip, CC0
const CACHE = path.join(ROOT, '.usda-cache');
const OUT = path.join(ROOT, 'assets', 'data', 'amino.json');

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

async function findFile(dir, name) {
  for (const entry of await readdir(dir, { withFileTypes: true, recursive: true })) {
    if (entry.isFile() && entry.name.toLowerCase() === name.toLowerCase()) {
      return path.join(entry.parentPath ?? entry.path ?? dir, entry.name);
    }
  }
  throw new Error(`${name} introuvable dans ${dir}`);
}

async function main() {
  let dir = arg('--dir');
  if (!dir) {
    dir = path.join(CACHE, 'sr');
    if (!existsSync(dir)) {
      await mkdir(CACHE, { recursive: true });
      process.stdout.write(`Téléchargement ${URL} ... `);
      const res = await fetch(URL, { headers: { 'User-Agent': 'Caillou-data-builder (https://github.com/remigl/caillou)' } });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const zip = path.join(CACHE, 'sr.zip');
      await writeFile(zip, Buffer.from(await res.arrayBuffer()));
      console.log('ok');
      await mkdir(dir, { recursive: true });
      execFileSync('unzip', ['-o', '-q', zip, '-d', dir]);
    }
  }

  const read = async (name) => (await readFile(await findFile(dir, name))).toString('latin1');
  const foods = parseSrFile(await read('FOOD_DES.txt')).map((r) => ({ ndb: r[0], desc: r[2] }));
  const defs = parseSrFile(await read('NUTR_DEF.txt')).map((r) => ({ nutr: r[0], desc: r[3] }));
  const nutrients = parseSrFile(await read('NUT_DATA.txt')).map((r) => ({ ndb: r[0], nutr: r[1], val: r[2] }));
  console.log(`${foods.length} aliments USDA, ${defs.length} nutriments, ${nutrients.length} valeurs.`);

  const ciqualJson = JSON.parse(await readFile(path.join(ROOT, 'assets', 'data', 'ciqual.json'), 'utf8'));
  const pIdx = ciqualJson.nutrients.indexOf('proteins');
  const ciqual = ciqualJson.foods.map((f) => ({ c: f.c, n: f.n, e: f.e, g: f.g, protein: typeof f.v[pIdx] === 'number' ? f.v[pIdx] : 0 }));

  const { dataset, stats } = buildAmino({ foods, nutrients, defs, ciqual });
  console.log(`${stats.usdaWithAmino} aliments USDA avec acides aminés ; ${stats.matched} aliments Ciqual rapprochés.`);
  console.log('Exemples :');
  for (const s of stats.samples.filter((_, i) => i % Math.max(1, Math.floor(stats.samples.length / 60)) === 0)) {
    console.log(`  ${s}`);
  }
  if (stats.matched < 50) throw new Error('Moins de 50 correspondances : conversion suspecte.');
  await writeFile(OUT, JSON.stringify(dataset));
  console.log(`Écrit : ${path.relative(ROOT, OUT)}`);
}

main().catch((e) => {
  console.error(`Échec : ${e.message}`);
  process.exit(1);
});
