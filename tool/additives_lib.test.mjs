import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildAdditives } from './additives_lib.mjs';

test('taxonomie des additifs -> table compacte', () => {
  const t = buildAdditives({
    'en:e330': { name: { en: 'Citric acid', fr: 'Acide citrique' }, additives_classes: { en: 'en:acid, en:acidity-regulator' } },
    'en:e322': { name: { en: 'E322 - Lecithins' } },
    'en:e150d': { name: { fr: 'Caramel au sulfite d\'ammonium' }, additives_classes: { en: 'en:colour' } },
    'en:colour': { name: { fr: 'Colorant' } },
    'en:e999': {},
  });
  assert.deepEqual(t.e330, ['Acide citrique', "Acidifiant, correcteur d'acidité"]);
  assert.deepEqual(t.e322, ['Lecithins']);
  assert.deepEqual(t.e150d, ["Caramel au sulfite d'ammonium", 'Colorant']);
  assert.equal(t.colour, undefined);
  assert.equal(t.e999, undefined);
});
