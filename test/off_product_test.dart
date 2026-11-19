import 'package:caillou/core/nutrients.dart';
import 'package:caillou/data/off/off_api.dart';
import 'package:caillou/data/off/off_product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parse un produit complet (réponse API v3.4)', () {
    final p = OffProduct.fromJson({
      'code': '8076800195057',
      'product_name': 'Spaghetti n°5',
      'product_name_fr': 'Spaghetti n°5',
      'brands': 'Barilla, Barilla Group',
      'quantity': '500 g',
      'image_front_url': 'https://images.openfoodfacts.org/x.jpg',
      'categories': 'Aliments d\'origine végétale, Pâtes alimentaires, Spaghetti',
      'ingredients_text_fr': 'Semoule de blé dur, eau.',
      'allergens_tags': ['en:gluten'],
      'traces_tags': ['en:soybeans', 'en:something-else'],
      'labels': 'en:Made in Italy, Point Vert',
      'nutriscore_grade': 'a',
      'nova_group': 1,
      'nutriments': {
        'energy-kcal_100g': 359,
        'energy-kj_100g': 1521,
        'fat_100g': 2,
        'saturated-fat_100g': 0.5,
        'carbohydrates_100g': 71.2,
        'sugars_100g': 3.5,
        'fiber_100g': 3,
        'proteins_100g': 13,
        'salt_100g': 0.013,
      },
    }, barcode: '8076800195057');

    expect(p.displayName, 'Spaghetti n°5');
    expect(p.brand, 'Barilla');
    expect(p.category, 'Spaghetti');
    expect(p.allergens, ['Gluten']);
    expect(p.traces, ['Soja', 'Something else']);
    expect(p.labels, ['Made in Italy', 'Point Vert']);
    expect(p.nutriScore, 'a');
    expect(p.nova, 1);
    expect(p.isLiquid, isFalse);
    expect(p.nutrition.energyKcal, const NutrientValue.exact(359));
    expect(p.nutrition.carbohydrates, const NutrientValue.exact(71.2));
    expect(p.nutrition.energySource, EnergySource.direct);
  });

  test('données manquantes : rien n\'est inventé', () {
    final p = OffProduct.fromJson({
      'product_name': '',
      'nutriscore_grade': 'unknown',
      'nova_group': '',
      'nutriments': {'sugars_100g': 4},
    }, barcode: '123456789');
    expect(p.name, isNull);
    expect(p.nutriScore, isNull);
    expect(p.nova, isNull);
    expect(p.nutrition.energyKcal.isAvailable, isFalse);
    expect(p.nutrition.fat.isAvailable, isFalse);
    expect(p.nutrition.sugars, const NutrientValue.exact(4));
  });

  test('kcal converties depuis kJ et signalées', () {
    final p = OffProduct.fromJson({
      'quantity': '1,5 L',
      'nutriments': {'energy_100g': 418.4},
    }, barcode: '12345678');
    expect(p.nutrition.energyKcal.value, closeTo(100, 0.001));
    expect(p.nutrition.energySource, EnergySource.convertedFromKj);
    expect(p.isLiquid, isTrue);
  });

  test('validation des codes-barres', () {
    expect(OffApi.cleanBarcode(' 3017 6204 22003 '), '3017620422003');
    expect(OffApi.cleanBarcode('abc'), isNull);
    expect(OffApi.cleanBarcode('123'), isNull);
  });
}
