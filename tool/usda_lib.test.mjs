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
  assert.ok(matchScore('Egg, hard-boiled', 'Egg, whole, cooked, hard-boiled') >= 0.6);
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
