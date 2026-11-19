import 'package:caillou/core/nutrients.dart';
import 'package:caillou/data/off/off_api.dart';
import 'package:caillou/data/off/off_product.dart';
import 'package:caillou/data/off/open_prices.dart';
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

  test('informations enrichies : additifs, analyse, repères, environnement, Ciqual', () {
    final p = OffProduct.fromJson({
      'additives_tags': ['en:e330', 'en:e150d'],
      'ingredients_analysis_tags': ['en:palm-oil-free', 'en:non-vegan', 'en:vegetarian'],
      'nutrient_levels': {'fat': 'low', 'sugars': 'high', 'salt': 'bizarre'},
      'environmental_score_grade': 'b',
      'environmental_score_data': {
        'agribalyse': {'co2_total': 1.53}
      },
      'origins': 'en:France, Italie',
      'categories': 'Aliments d\'origine végétale, Pâtes alimentaires, Spaghetti',
      'categories_properties': {'ciqual_food_code:en': '9811'},
      'nutriments': {'vitamin-c_100g': 0.012, 'calcium_100g': 0.12, 'vitamin-d_100g': 0.0000025},
    }, barcode: '12345678');
    expect(p.additives, ['e330', 'e150d']);
    expect(p.vegan, Tri.no);
    expect(p.vegetarian, Tri.yes);
    expect(p.palmOil, Tri.no);
    expect(p.nutrientLevels, {'fat': 'low', 'sugars': 'high'});
    expect(p.environmentalGrade, 'b');
    expect(p.co2PerKg, 1.53);
    expect(p.origins, 'France, Italie');
    expect(p.ciqualCode, 9811);
    expect(p.categories.last, 'Spaghetti');
    final extras = {for (final e in p.extraNutrients) e.label: '${e.value.formatAmount()} ${e.unit}'};
    expect(extras['Vitamine C'], '12 mg');
    expect(extras['Calcium'], '120 mg');
    expect(extras['Vitamine D'], '2,5 µg');
  });

  test('ancien nom du score environnemental et données absentes', () {
    final p = OffProduct.fromJson({'ecoscore_grade': 'unknown', 'ecoscore_data': {'agribalyse': {}}}, barcode: '12345678');
    expect(p.environmentalGrade, isNull);
    expect(p.co2PerKg, isNull);
    expect(p.vegan, Tri.unknown);
    expect(p.extraNutrients, isEmpty);
    expect(p.ciqualCode, isNull);
  });

  test('Open Prices : parsing tolérant', () {
    final prices = parsePrices({
      'items': [
        {
          'price': 1.29,
          'currency': 'EUR',
          'date': '2026-11-02',
          'location': {'osm_name': 'Carrefour Market', 'osm_address_city': 'Lyon'},
          'price_is_discounted': true,
        },
        {'price': 'x', 'currency': 'EUR'},
        {'price': 2.5, 'currency': 'EUR', 'price_per': 'KILOGRAM'},
      ],
    });
    expect(prices, hasLength(2));
    expect(prices.first.place, 'Carrefour Market, Lyon');
    expect(prices.first.discounted, isTrue);
    expect(prices.last.perKilo, isTrue);
    expect(formatPrice(1.29, 'EUR'), '1,29 €');
    expect(parsePrices('nimporte quoi'), isEmpty);
  });
}
