import 'package:caillou/core/nutrients.dart';
import 'package:caillou/core/reference_intakes.dart';
import 'package:caillou/data/amino.dart';
import 'package:caillou/data/ciqual/ciqual_food.dart';
import 'package:caillou/data/ciqual/food_index.dart';
import 'package:caillou/data/meal.dart';
import 'package:caillou/data/meal_suggestions.dart';
import 'package:caillou/data/recalls.dart';
import 'package:flutter_test/flutter_test.dart';

CiqualFood f(int code, String name, {double? kcal, double? protein, double? carbs, double? fiber, String? group}) =>
    CiqualFood(
      code: code,
      name: name,
      group: group,
      nutrition: Nutrition(
        energyKcal: kcal == null ? NutrientValue.missing : NutrientValue.exact(kcal),
        proteins: protein == null ? NutrientValue.missing : NutrientValue.exact(protein),
        carbohydrates: carbs == null ? NutrientValue.missing : NutrientValue.exact(carbs),
        fiber: fiber == null ? NutrientValue.missing : NutrientValue.exact(fiber),
      ),
    );

FoodIndex index() => FoodIndex(CiqualDataset(source: 't', licence: 't', version: 't', foods: [
      f(1, 'Pâtes sèches, standard, cuites, sans sel ajouté', kcal: 150, protein: 5.5, carbs: 30, fiber: 1.8, group: 'pâtes, riz et céréales'),
      f(2, 'Lentille verte, cuite', kcal: 120, protein: 9, carbs: 16, fiber: 8, group: 'légumineuses'),
      f(3, 'Brocoli, cuit', kcal: 29, protein: 2.5, carbs: 2, fiber: 2.6, group: 'légumes'),
      f(4, 'Orange, pulpe, crue', kcal: 45, protein: 0.9, carbs: 9, fiber: 2, group: 'fruits'),
      f(5, 'Oeuf dur', kcal: 134, protein: 13, carbs: 0.5, group: 'oeufs'),
      f(6, 'Carotte, crue', kcal: 36, protein: 0.6, carbs: 7, fiber: 2.7, group: 'légumes'),
    ]));

void main() {
  group('Valeurs de référence (UE 1169/2011)', () {
    test('VNR par libellé Ciqual ou Open Food Facts', () {
      expect(nrvFor('Vitamine C')!.amount, 80);
      expect(nrvFor('Vitamine B9 ou Folates totaux')!.unit, 'µg');
      expect(nrvFor('Vitamine B9 (folates)')!.amount, 200);
      expect(nrvFor('Fer')!.amount, 14);
      expect(nrvFor('Vitamine B12')!.amount, 2.5);
      expect(nrvFor('Vitamine B1 ou Thiamine')!.amount, 1.1);
      expect(nrvFor('Vitamine D3'), isNull);
      expect(nrvFor('Eau'), isNull);
    });

    test('pourcentages et conversions d\'unités', () {
      expect(percentOf(const NutrientValue.exact(91.2), 'mg', nrvFor('Vitamine C'))!.round(), 114);
      expect(percentOf(const NutrientValue.exact(0.0912), 'g', nrvFor('Vitamine C'))!.round(), 114);
      expect(percentOf(const NutrientValue.exact(52), 'kcal', MacroReferences.energyKcal), closeTo(2.6, 1e-9));
      expect(percentOf(NutrientValue.traces, 'mg', nrvFor('Fer')), isNull);
      expect(formatPercent(0.4), '< 1 %');
      expect(formatPercent(114.3), '114 %');
    });

    test('repère 10 g de glucides', () {
      expect(gramsFor10gCarbs(const NutrientValue.exact(25))!.round(), 40);
      expect(gramsFor10gCarbs(const NutrientValue.exact(0.5)), isNull);
      expect(gramsFor10gCarbs(NutrientValue.missing), isNull);
    });
  });

  group('Repas', () {
    test('totaux pondérés par la quantité, valeurs manquantes signalées', () {
      final idx = index();
      final pates = MealItem.fromFood(idx.byCode(1)!, const [], grams: 200);
      final oeuf = MealItem.fromFood(idx.byCode(5)!, const [], grams: 50);
      final t = MealTotals([pates, oeuf]);
      expect(t.grams, 250);
      expect(t.value('kcal'), closeTo(300 + 67, 1e-9));
      expect(t.value('proteins'), closeTo(11 + 6.5, 1e-9));
      // Fibres absentes pour l'œuf : total incomplet, mais pas « non disponible ».
      expect(t.nutrition.fiber.isAvailable, isTrue);
      expect(t.incompleteItems, contains('Oeuf dur'));
      // Lipides absents partout : non disponible plutôt que 0.
      expect(t.nutrition.fat.isAvailable, isFalse);
    });

    test('sérialisation d\'un élément de repas', () {
      final item = MealItem.fromFood(index().byCode(3)!, const [], grams: 150);
      final back = MealItem.fromJson(item.toJson())!;
      expect(back.key, 'ciqual:3');
      expect(back.grams, 150);
      expect(back.per100.energyKcal, const NutrientValue.exact(29));
      expect(back.per100.fat, NutrientValue.missing);
      expect(back.isFruitOrVegetable, isTrue);
    });

    test('suggestions : des pâtes seules appellent protéines, légumes et fruit', () {
      final idx = index();
      final s = MealSuggester(idx).suggest([MealItem.fromFood(idx.byCode(1)!, const [], grams: 150)]);
      final titles = s.map((x) => x.title).toList();
      expect(titles, contains('Une source de protéines'));
      expect(titles, contains('Des légumes'));
      expect(titles, contains('Un fruit'));
      expect(titles, isNot(contains('Un féculent'))); // déjà 45 g de glucides
      final veg = s.firstWhere((x) => x.title == 'Des légumes');
      expect(veg.foods.every((food) => food.group == 'légumes'), isTrue);
      // Les aliments déjà présents ne sont jamais proposés.
      expect(s.expand((x) => x.foods).any((food) => food.code == 1), isFalse);
    });

    test('repas équilibré : pas de suggestion inutile', () {
      final idx = index();
      final s = MealSuggester(idx).suggest([
        MealItem.fromFood(idx.byCode(1)!, const [], grams: 200),
        MealItem.fromFood(idx.byCode(2)!, const [], grams: 200),
        MealItem.fromFood(idx.byCode(3)!, const [], grams: 200),
        MealItem.fromFood(idx.byCode(4)!, const [], grams: 150),
      ]);
      expect(s, isEmpty);
    });
  });

  group('Rappels de produits', () {
    test('RappelConso : seulement les fiches qui contiennent le code', () {
      final r = parseRappelConso({
        'total_count': 2,
        'results': [
          {
            'id': 'a1',
            'libelle': 'Pâte à tartiner',
            'marque_produit': 'Marque X',
            'gtin': 3017620422003,
            'motif_rappel': 'Présence de salmonelles',
            'risques_encourus': 'Salmonellose',
            'date_publication': '2026-03-02',
            'lien_vers_la_fiche_rappel': 'https://rappel.conso.gouv.fr/fiche-rappel/1',
          },
          {'id': 'b2', 'libelle': 'Autre produit', 'gtin': 1234567890123},
        ],
      }, '3017620422003');
      expect(r, hasLength(1));
      expect(r.single.title, 'Pâte à tartiner — Marque X');
      expect(r.single.reason, 'Présence de salmonelles');
      expect(r.single.date, DateTime(2026, 3, 2));
    });

    test('openFDA et codes UPC nord-américains', () {
      expect(northAmericanUpc('0012345678905'), '012345678905');
      expect(northAmericanUpc('3017620422003'), isNull);
      final r = parseOpenFda({
        'results': [
          {
            'product_description': 'Peanut butter 16 oz',
            'code_info': 'UPC 012345678905, lot 123',
            'reason_for_recall': 'Salmonella',
            'classification': 'Class I',
            'recall_initiation_date': '20260105',
          }
        ]
      }, '012345678905');
      expect(r.single.source, 'FDA (États-Unis)');
      expect(r.single.date, DateTime(2026, 1, 5));
      expect(parseOpenFda({'error': {}}, '012345678905'), isEmpty);
    });
  });

  test('acides aminés : correspondance USDA et valeurs absentes ignorées', () {
    final data = <String, dynamic>{
      'names': ['Leucine', 'Lysine', 'Alanine'],
      'essential': [true, true, false],
      'usda': [
        {'n': '16070', 'd': 'Lentils, mature seeds, cooked', 'v': [0.65, null, 0.38]},
      ],
      'ciqual': {'20501': 0},
    };
    final p = parseAmino(data, 20501)!;
    expect(p.usdaName, 'Lentils, mature seeds, cooked');
    expect(p.values.map((v) => v.$1), ['Leucine', 'Alanine']);
    expect(p.values.first.$2, isTrue);
    expect(parseAmino(data, 1), isNull);
  });
}
