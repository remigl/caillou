import { test } from 'node:test';
import assert from 'node:assert/strict';
import { analyzeName, buildAmino, matchScore, parseSrLine, AMINO_ACIDS } from './usda_lib.mjs';

test('lignes SR', () => {
  assert.deepEqual(parseSrLine('~01001~^~0100~^~Butter, salted~^1.5\r'), ['01001', '0100', 'Butter, salted', '1.5']);
});

test('analyse des noms', () => {
  const a = analyzeName('Lentils, mature seeds, cooked, boiled, without salt');
  assert.deepEqual(a.tokens, ['lentil']);
  assert.ok(a.states.has('cooked'));
  assert.equal(analyzeName('Egg, whole, cooked, hard-boiled').head, 'egg');
});

test('correspondances : même aliment, même état', () => {
  assert.ok(matchScore('Lentil, green, cooked', 'Lentils, mature seeds, cooked, boiled, without salt') >= 0.6);
  assert.ok(matchScore('Broccoli, raw', 'Broccoli, raw') > 1);
  assert.equal(matchScore('Broccoli, raw', 'Broccoli, cooked, boiled, drained, without salt'), 0); // cru ≠ cuit
  assert.equal(matchScore('Apple, raw', 'Pineapple, raw'), 0); // nom principal différent
  assert.ok(matchScore('Egg, hard-boiled', 'Egg, whole, cooked, hard-boiled') > matchScore('Egg, hard-boiled', 'Egg, whole, cooked, fried'));
  // Cas réels refusés : état différent, plat composé, transformation.
  assert.equal(matchScore('Lentil, green, dried', 'Lentils, mature seeds, cooked, boiled, with salt'), 0);
  assert.equal(matchScore('Kidney bean, canned, drained', 'Beans, kidney, red, mature seeds, raw'), 0);
  assert.equal(matchScore('Chicken tajine, prepacked', 'Chicken, skin (drumsticks and thighs), raw'), 0);
  assert.equal(matchScore('Couscous with fish', 'Couscous, cooked'), 0);
  assert.equal(matchScore('Fresh pasta, with eggs, raw', 'Egg, whole, raw, fresh'), 0);
  assert.equal(matchScore('Egg, white, cooked', 'Egg, whole, cooked, fried'), 0);
  assert.equal(matchScore('Green bean, cooked', 'Beans, french, mature seeds, cooked, boiled, with salt'), 0);
  assert.equal(matchScore('Tofu, plain, prepacked', 'Tofu, fried'), 0);
  assert.equal(matchScore('Beef, minced steak, 5% fat, raw', 'Beef, flank, steak, separable lean only, trimmed to 0" fat, choice, raw'), 0);
  assert.ok(matchScore('Beef, minced steak, 5% fat, raw', 'Beef, ground, 95% lean meat / 5% fat, raw') > 0);
  assert.ok(matchScore('Lentil, boiled/cooked in water', 'Lentils, mature seeds, cooked, boiled, with salt') >= 0.7);
  assert.equal(matchScore('Peanut, roasted, flavoured', 'Peanuts, all types, cooked, boiled, with salt'), 0);
  assert.equal(matchScore('French bean, cooked', 'Beans, french, mature seeds, cooked, boiled, with salt'), 0);
  assert.equal(matchScore('Chicken, fillet, without skin, raw', 'Chicken, broilers or fryers, breast, meat and skin, raw'), 0);
  assert.ok(matchScore('Egg, white, raw', 'Egg, white, raw, fresh') > 0);
});

test('plats composés exclus', () => {
  const defs = AMINO_ACIDS.map(([name], i) => ({ nutr: String(501 + i), desc: name }));
  const foods = [{ ndb: '1', desc: 'Beans, white, mature seeds, canned' }];
  const nutrients = defs.map((d) => ({ ndb: '1', nutr: d.nutr, val: '0.5' }));
  const ciqual = [
    { c: 1, n: 'Cassoulet, appertisé', e: 'Beans, white, canned', g: 'plats composés', protein: 8 },
    { c: 2, n: 'Haricot blanc, appertisé', e: 'White bean, canned', g: 'légumineuses', protein: 7 },
  ];
  const { dataset } = buildAmino({ foods, nutrients, defs, ciqual });
  assert.equal(dataset.ciqual[1], undefined);
  assert.equal(dataset.ciqual[2], 0);
});

test('construction du jeu de données', () => {
  const defs = AMINO_ACIDS.map(([name], i) => ({ nutr: String(501 + i), desc: name }));
  const foods = [
    { ndb: '11090', desc: 'Broccoli, raw' },
    { ndb: '16070', desc: 'Lentils, mature seeds, cooked, boiled, without salt' },
    { ndb: '09003', desc: 'Apples, raw, with skin' },
  ];
  const nutrients = [];
  for (const f of foods.slice(0, 2)) {
    defs.forEach((d, i) => nutrients.push({ ndb: f.ndb, nutr: d.nutr, val: String(0.1 + i / 100) }));
  }
  const ciqual = [
    { c: 20057, n: 'Brocoli, cru', e: 'Broccoli, raw', protein: 2.8 },
    { c: 20501, n: 'Lentille verte, cuite', e: 'Lentil, green, cooked', protein: 9 },
    { c: 13000, n: 'Pomme, crue', e: 'Apple, raw', protein: 0.3 },
    { c: 99999, n: 'Ananas', e: 'Pineapple, raw', protein: 2.5 },
  ];
  const { dataset, stats } = buildAmino({ foods, nutrients, defs, ciqual });
  assert.equal(stats.matched, 2);
  assert.equal(dataset.usda[dataset.ciqual[20057]].d, 'Broccoli, raw');
  assert.equal(dataset.usda[dataset.ciqual[20501]].n, '16070');
  assert.equal(dataset.ciqual[13000], undefined); // pomme : trop peu de protéines (et pas d'acides aminés)
  assert.equal(dataset.ciqual[99999], undefined);
  assert.equal(dataset.names.length, 18);
  assert.equal(dataset.usda[0].v.length, 18);
});
