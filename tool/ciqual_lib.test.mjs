// Tests du convertisseur Ciqual : node --test tool/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildDataset, decodeXml, parseRecords, parseTeneur, splitUnit, friendlyLabel, detailGroup, NUTRIENT_KEYS } from './ciqual_lib.mjs';

const CONST_XML = `<?xml version="1.0" encoding="UTF-8"?>
<TABLE>
<CONST><const_code> 327 </const_code><const_nom_fr> Energie, Règlement UE N° 1169/2011 (kJ/100 g) </const_nom_fr></CONST>
<CONST><const_code> 328 </const_code><const_nom_fr> Energie, Règlement UE N° 1169/2011 (kcal/100 g) </const_nom_fr></CONST>
<CONST><const_code> 332 </const_code><const_nom_fr> Energie, N x facteur Jones, avec fibres  (kJ/100 g) </const_nom_fr></CONST>
<CONST><const_code> 333 </const_code><const_nom_fr> Energie, N x facteur Jones, avec fibres  (kcal/100 g) </const_nom_fr></CONST>
<CONST><const_code> 25000 </const_code><const_nom_fr> Protéines, N x facteur de Jones (g/100 g) </const_nom_fr></CONST>
<CONST><const_code> 25003 </const_code><const_nom_fr> Protéines, N x 6.25 (g/100 g) </const_nom_fr></CONST>
<CONST><const_code> 31000 </const_code><const_nom_fr> Glucides (g/100 g) </const_nom_fr></CONST>
<CONST><const_code> 32000 </const_code><const_nom_fr> Sucres (g/100 g) </const_nom_fr></CONST>
<CONST><const_code> 34100 </const_code><const_nom_fr> Fibres alimentaires (g/100 g) </const_nom_fr></CONST>
<CONST><const_code> 40000 </const_code><const_nom_fr> Lipides (g/100 g) </const_nom_fr></CONST>
<CONST><const_code> 40302 </const_code><const_nom_fr> AG saturés (g/100 g) </const_nom_fr></CONST>
<CONST><const_code> 10004 </const_code><const_nom_fr> Sel chlorure de sodium (g/100 g) </const_nom_fr></CONST>
<CONST><const_code> 400 </const_code><const_nom_fr> Eau (g/100 g) </const_nom_fr></CONST>
<CONST><const_code> 10200 </const_code><const_nom_fr> Calcium (mg/100 g) </const_nom_fr></CONST>
<CONST><const_code> 55100 </const_code><const_nom_fr> Vitamine C (mg/100 g) </const_nom_fr></CONST>
<CONST><const_code> 41833 </const_code><const_nom_fr> AG 18:3 c9,c12,c15 (n-3), alpha-linolénique (g/100 g) </const_nom_fr></CONST>
</TABLE>`;

const ALIM_XML = `<TABLE>
<ALIM><alim_code> 13000 </alim_code><alim_nom_fr> Pomme, pulpe et peau, crue </alim_nom_fr><alim_nom_eng> Apple, pulp and peel, raw </alim_nom_eng><alim_grp_code> 02 </alim_grp_code><alim_ssgrp_code> 0204 </alim_ssgrp_code></ALIM>
<ALIM><alim_code> 20057 </alim_code><alim_nom_fr> Brocoli, cru </alim_nom_fr><alim_ssgrp_code> 0201 </alim_ssgrp_code></ALIM>
</TABLE>`;

const GRP_XML = `<TABLE>
<ALIM_GRP><alim_grp_code> 02 </alim_grp_code><alim_grp_nom_fr> fruits, légumes </alim_grp_nom_fr><alim_ssgrp_code> 0204 </alim_ssgrp_code><alim_ssgrp_nom_fr> fruits </alim_ssgrp_nom_fr></ALIM_GRP>
<ALIM_GRP><alim_grp_code> 02 </alim_grp_code><alim_ssgrp_code> 0201 </alim_ssgrp_code><alim_ssgrp_nom_fr> légumes </alim_ssgrp_nom_fr></ALIM_GRP>
</TABLE>`;

const COMPO_XML = `<TABLE>
<COMPO><alim_code> 13000 </alim_code><const_code> 333 </const_code><teneur> 52,3 </teneur><min missing=" " /><code_confiance> A </code_confiance></COMPO>
<COMPO><alim_code> 13000 </alim_code><const_code> 332 </const_code><teneur> 219 </teneur></COMPO>
<COMPO><alim_code> 13000 </alim_code><const_code> 328 </const_code><teneur> - </teneur></COMPO>
<COMPO><alim_code> 13000 </alim_code><const_code> 31000 </const_code><teneur> 13,8 </teneur></COMPO>
<COMPO><alim_code> 13000 </alim_code><const_code> 40000 </const_code><teneur> &lt; 0,5 </teneur></COMPO>
<COMPO><alim_code> 13000 </alim_code><const_code> 10004 </const_code><teneur> traces </teneur></COMPO>
<COMPO><alim_code> 13000 </alim_code><const_code> 25003 </const_code><teneur> 0,3 </teneur></COMPO>
<COMPO><alim_code> 20057 </alim_code><const_code> 328 </const_code><teneur> 34 </teneur></COMPO>
<COMPO><alim_code> 20057 </alim_code><const_code> 25000 </const_code><teneur> 2,8 </teneur></COMPO>
<COMPO><alim_code> 20057 </alim_code><const_code> 400 </const_code><teneur> 89 </teneur></COMPO>
<COMPO><alim_code> 20057 </alim_code><const_code> 55100 </const_code><teneur> 89,2 </teneur></COMPO>
<COMPO><alim_code> 20057 </alim_code><const_code> 10200 </const_code><teneur> - </teneur></COMPO>
</TABLE>`;

test('parseTeneur', () => {
  assert.equal(parseTeneur(' 0,2 '), 0.2);
  assert.equal(parseTeneur('-'), null);
  assert.equal(parseTeneur(''), null);
  assert.equal(parseTeneur('traces'), 'traces');
  assert.equal(parseTeneur('< 0,5'), '<0.5');
  assert.equal(parseTeneur('n/a'), undefined);
});

test('decodeXml gère windows-1252', () => {
  const buf = Buffer.concat([
    Buffer.from('<?xml version="1.0" encoding="windows-1252"?><TABLE><CONST><const_nom_fr>Prot'),
    Buffer.from([0xe9]),
    Buffer.from('ines</const_nom_fr></CONST></TABLE>'),
  ]);
  assert.equal(parseRecords(decodeXml(buf), 'CONST')[0].const_nom_fr, 'Protéines');
});

test('buildDataset : correspondances, valeurs manquantes, repli énergie', () => {
  const { dataset, stats } = buildDataset({
    alim: parseRecords(ALIM_XML, 'ALIM'),
    compo: parseRecords(COMPO_XML, 'COMPO'),
    constants: parseRecords(CONST_XML, 'CONST'),
    groups: parseRecords(GRP_XML, 'ALIM_GRP'),
    version: 'test',
    source: 'test',
  });
  assert.equal(stats.foods, 2);
  const byCode = Object.fromEntries(dataset.foods.map((f) => [f.c, f]));
  const val = (food, key) => food.v[NUTRIENT_KEYS.indexOf(key)];

  const pomme = byCode[13000];
  assert.equal(pomme.g, 'fruits');
  assert.equal(pomme.e, 'Apple, pulp and peel, raw');
  assert.equal(val(pomme, 'kcal'), 52.3); // repli Jones
  assert.equal(val(pomme, 'kj'), 219);
  assert.equal(pomme.ef, 1);
  assert.equal(val(pomme, 'carbs'), 13.8);
  assert.equal(val(pomme, 'fat'), '<0.5');
  assert.equal(val(pomme, 'salt'), 'traces');
  assert.equal(val(pomme, 'proteins'), 0.3); // N x 6,25 en repli
  assert.equal(val(pomme, 'fiber'), null); // absent -> null, jamais 0

  const brocoli = byCode[20057];
  assert.equal(val(brocoli, 'kcal'), 34);
  assert.equal(brocoli.ef, undefined);
  assert.equal(val(brocoli, 'proteins'), 2.8);
  assert.equal(val(brocoli, 'kj'), null);
});

test('buildDataset échoue si un constituant obligatoire manque', () => {
  assert.throws(() =>
    buildDataset({ alim: [], compo: [], constants: [], groups: [], version: 't', source: 't' }),
  );
});

test('composition détaillée : unités, libellés, groupes', () => {
  assert.deepEqual(splitUnit('Vitamine B9 ou Folates totaux (µg/100 g)'), { label: 'Vitamine B9 ou Folates totaux', unit: 'µg' });
  assert.equal(friendlyLabel('AG 22:6 4c,7c,10c,13c,16c,19c (n-3) DHA'), 'Oméga-3 : DHA');
  assert.equal(detailGroup('Calcium'), 'Minéraux et oligo-éléments');
  assert.equal(detailGroup('Vitamine C'), 'Vitamines');
  assert.equal(detailGroup('Amidon'), 'Glucides');
  assert.equal(detailGroup('Eau'), 'Autres');
  assert.equal(detailGroup('Alpha-tocophérol (vitamine E)'), 'Vitamines');
  assert.equal(detailGroup('Folates intrinsèques'), 'Vitamines');

  const { dataset } = buildDataset({
    alim: parseRecords(ALIM_XML, 'ALIM'),
    compo: parseRecords(COMPO_XML, 'COMPO'),
    constants: parseRecords(CONST_XML, 'CONST'),
    groups: parseRecords(GRP_XML, 'ALIM_GRP'),
    version: 'test',
    source: 'test',
  });
  assert.equal(dataset.formatVersion, 2);
  const names = dataset.details.map((d) => d.n);
  assert.ok(names.includes('Vitamine C') && names.includes('Calcium') && names.includes('Eau'));
  assert.ok(names.includes('Oméga-3 : acide alpha-linolénique (ALA)'));
  assert.ok(!names.some((n) => /Lipides|Energie|Protéines/.test(n))); // déjà dans le tableau principal
  const brocoli = dataset.foods.find((f) => f.c === 20057);
  const vitC = names.indexOf('Vitamine C');
  const ca = names.indexOf('Calcium');
  const pairs = Object.fromEntries(brocoli.d.reduce((acc, x, i, arr) => (i % 2 ? acc : [...acc, [arr[i], arr[i + 1]]]), []));
  assert.equal(pairs[vitC], 89.2);
  assert.equal(pairs[ca], undefined); // absent -> non stocké
});
