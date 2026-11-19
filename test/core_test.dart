import 'package:caillou/core/nutrients.dart';
import 'package:caillou/core/text.dart';
import 'package:caillou/data/food_aliases.dart';
import 'package:caillou/data/history_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NutrientValue', () {
    test('Ciqual : nombre, traces, inférieur à, absent', () {
      expect(NutrientValue.fromCiqual(13.8), const NutrientValue.exact(13.8));
      expect(NutrientValue.fromCiqual('traces'), NutrientValue.traces);
      expect(NutrientValue.fromCiqual('<0.5'), const NutrientValue.lessThan(0.5));
      expect(NutrientValue.fromCiqual(null), NutrientValue.missing);
      expect(NutrientValue.fromCiqual('???'), NutrientValue.missing);
    });

    test('Open Food Facts : absent ou invalide reste absent, jamais 0', () {
      expect(NutrientValue.fromOff(null).isAvailable, isFalse);
      expect(NutrientValue.fromOff('').isAvailable, isFalse);
      expect(NutrientValue.fromOff(-1).isAvailable, isFalse);
      expect(NutrientValue.fromOff('2,5'), const NutrientValue.exact(2.5));
      expect(NutrientValue.fromOff(0), const NutrientValue.exact(0));
    });

    test('format français', () {
      expect(formatDecimal(13.8), '13,8');
      expect(formatDecimal(0.3), '0,3');
      expect(formatDecimal(0.25), '0,25');
      expect(formatDecimal(52), '52');
      expect(formatDecimal(0), '0');
      expect(const NutrientValue.lessThan(0.5).formatAmount(), '< 0,5');
      expect(const NutrientValue.exact(52.4).formatEnergy(), '52');
      expect(NutrientValue.missing.formatAmount(), isNull);
    });
  });

  group('Texte', () {
    test('normalisation et pluriels', () {
      expect(normalizeText('Pâtes alimentaires, cuites'), 'pates alimentaires cuites');
      expect(normalizeText('Œuf'), 'oeuf');
      expect(tokenize('Carottes râpées'), ['carotte', 'rapee']);
      expect(tokenize('noix'), ['noix']);
    });
  });

  group('Alias reconnaissance -> français', () {
    test('noms anglais et pluriels', () {
      expect(FoodAliases.lookup('broccoli')?.name, 'brocoli');
      expect(FoodAliases.lookup('Apple')?.name, 'pomme');
      expect(FoodAliases.lookup('carrots')?.name, 'carotte');
      expect(FoodAliases.lookup('bananas')?.name, 'banane');
      expect(FoodAliases.lookup('cherry tomatoes')?.name, 'tomate cerise');
      expect(FoodAliases.lookup('Tomates')?.name, 'tomate');
      expect(FoodAliases.lookup('licorne'), isNull);
    });

    test('expansion de requête exacte uniquement (« pâté » n\'est pas « pâtes »)', () {
      expect(FoodAliases.expansionFor('pâtes'), 'pates seches');
      expect(FoodAliases.expansionFor('pâté'), isNull);
      expect(FoodAliases.expansionFor('broccoli'), 'brocoli');
      expect(FoodAliases.expansionFor('brocoli'), isNull);
    });
  });

  test('historique : une photo et ses aliments survivent à la sérialisation', () {
    final e = HistoryEntry(
      kind: HistoryKind.photo,
      id: '42',
      title: 'Pomme, Banane',
      at: DateTime(2026, 11, 19, 12),
      items: const [
        {'n': 'Pomme', 'e': '🍎', 'c': 4, 'p': 0.97},
      ],
    );
    final back = HistoryEntry.fromJson(e.toJson())!;
    expect(back.kind, HistoryKind.photo);
    expect(back.items.single['c'], 4);
    expect(back.items.single['n'], 'Pomme');
  });
}
