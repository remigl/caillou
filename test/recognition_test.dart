import 'package:caillou/core/nutrients.dart';
import 'package:caillou/data/ciqual/ciqual_food.dart';
import 'package:caillou/data/ciqual/food_index.dart';
import 'package:caillou/recognition/food_matcher.dart';
import 'package:caillou/recognition/food_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

CiqualFood food(int code, String name, double kcal, {String? en, bool noEnergy = false}) => CiqualFood(
      code: code,
      name: name,
      nameEn: en,
      nutrition: Nutrition(energyKcal: noEnergy ? NutrientValue.missing : NutrientValue.exact(kcal)),
    );

FoodIndex sampleIndex() => FoodIndex(CiqualDataset(
      source: 'test',
      licence: 'test',
      version: 'test',
      foods: [
        food(1, 'Brocoli, cru', 34, en: 'Broccoli, raw'),
        food(2, 'Brocoli, cuit', 29, en: 'Broccoli, cooked'),
        food(3, 'Brocoli, surgelé, cru', 30),
        food(4, 'Pomme, pulpe et peau, crue', 52, en: 'Apple, pulp and peel, raw'),
        food(5, 'Pomme de terre, cuite à l\'eau', 80, en: 'Potato, boiled'),
        food(6, 'Compote de pomme', 70),
        food(7, 'Pâtes sèches, standard, cuites, sans sel ajouté', 167, en: 'Pasta, cooked'),
        food(8, 'Pâté (aliment moyen)', 325),
        food(9, 'Carotte, crue', 36, en: 'Carrot, raw'),
        food(10, 'Banane, pulpe, crue', 90, en: 'Banana, pulp, raw'),
        food(11, 'Tomate sans précision, crue (aliment moyen)', 19.2, en: 'Tomato, raw'),
        food(12, 'Tomate, séchée', 0, noEnergy: true),
        food(13, 'Tomate, entière, crue, prélevée à la Martinique', 0, noEnergy: true),
        food(14, 'Tomate, concentré, appertisé', 99.2),
        food(15, 'Oeuf, en poudre', 587),
        food(16, 'Oeuf dur', 134),
        food(17, 'Pomme, sèche', 247),
      ],
    ));

void main() {
  group('parseDetections', () {
    test('JSON attendu', () {
      final d = parseDetections(
          '{"foods":[{"name_en":"apple","name_fr":"pomme","state":"raw","confidence":0.97},'
          '{"name_en":"broccoli","name_fr":"brocoli","confidence":0.93}]}');
      expect(d, hasLength(2));
      expect(d.first.nameFr, 'pomme');
      expect(d.first.confidence, 0.97);
      expect(d.first.state, 'raw');
    });

    test('bloc ```json, pourcentage, confiance manquante', () {
      final d = parseDetections('Voici :\n```json\n[{"name":"banana","confidence":95},{"name_fr":"carotte"}]\n```');
      expect(d.first.nameEn, 'banana');
      expect(d.first.confidence, 0.95);
      expect(d.last.confidence, 0); // absente -> à vérifier, jamais validée d'office
    });

    test('réponse illisible', () {
      expect(() => parseDetections('désolé'), throwsA(isA<RecognitionException>()));
    });
  });

  group('Recherche Ciqual', () {
    final index = sampleIndex();

    test('« pomme » propose la pomme avant la pomme de terre', () {
      final r = index.search('pomme');
      expect(r.first.code, 4);
      expect(r.map((f) => f.code), containsAll([5, 6]));
    });

    test('« pâtes » trouve les pâtes alimentaires avant le pâté', () {
      expect(index.search('pâtes').first.code, 7);
    });

    test('cru et cuit sont distingués', () {
      final r = index.search('brocoli');
      expect(r.take(3).map((f) => f.code), containsAll([1, 2, 3]));
      expect(index.byCode(2)!.states, contains(FoodState.cooked));
      expect(index.byCode(1)!.states, contains(FoodState.raw));
      expect(index.variantsOf(index.byCode(1)!).map((f) => f.code), containsAll([2, 3]));
    });

    test('aliment moyen avant échantillons régionaux, séchés, conserves', () {
      expect(index.search('tomate').first.code, 11);
      expect(index.search('pâté').first.code, 8);
      expect(index.search('oeuf').first.code, 16);
      expect(index.byCode(17)!.states, contains(FoodState.dried));
      expect(index.byCode(7)!.states, isNot(contains(FoodState.dried))); // « pâtes sèches »
    });

    test('nom anglais en repli', () {
      expect(index.search('broccoli').first.code, 1);
      expect(index.search('pasta').first.code, 7);
    });
  });

  group('Correspondance photo -> fiche', () {
    final matcher = FoodMatcher(sampleIndex());

    test('noms anglais normalisés et dédoublonnés', () {
      final items = matcher.resolveAll(const [
        DetectedFood(nameEn: 'apple', nameFr: '', confidence: 0.97),
        DetectedFood(nameEn: 'broccoli', nameFr: 'brocoli', confidence: 0.93),
        DetectedFood(nameEn: 'carrots', nameFr: '', confidence: 0.96),
        DetectedFood(nameEn: 'banana', nameFr: 'banane', confidence: 0.95),
        DetectedFood(nameEn: 'tomato', nameFr: 'tomate', confidence: 0.4),
        DetectedFood(nameEn: 'tomatoes', nameFr: 'tomates', confidence: 0.3),
        DetectedFood(nameEn: 'egg', nameFr: 'œuf', confidence: 0.9),
      ]);
      final byName = {for (final i in items) i.displayName: i};
      expect(byName['Pomme']!.match!.code, 4);
      expect(byName['Brocoli']!.match!.code, 1); // cru par défaut
      expect(byName['Carotte']!.match!.code, 9);
      expect(byName['Banane']!.match!.code, 10);
      expect(items.where((i) => i.match?.code == 11), hasLength(1));
      expect(byName['Tomate']!.needsReview, isTrue);
      expect(byName['Pomme']!.needsReview, isFalse);
      expect(byName['Œuf']!.match!.code, 16);
    });

    test('état cuit détecté sur la photo', () {
      final item = matcher.resolve(const DetectedFood(nameEn: 'broccoli', nameFr: 'brocoli', confidence: 0.9, state: 'cooked'));
      expect(item.match!.code, 2);
    });

    test('aliment inconnu : pas de fiche inventée', () {
      final item = matcher.resolve(const DetectedFood(nameEn: 'dragon fruit', nameFr: 'pitaya', confidence: 0.8));
      expect(item.match, isNull);
      expect(item.displayName, 'Pitaya');
    });
  });
}
