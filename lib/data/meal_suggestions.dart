import 'ciqual/ciqual_food.dart';
import 'ciqual/food_index.dart';
import 'food_aliases.dart';
import 'meal.dart';

/// Une suggestion pour compléter le repas : une raison lisible et quelques aliments Ciqual.
class MealSuggestion {
  const MealSuggestion({required this.title, required this.reason, required this.foods, required this.grams});

  final String title;
  final String reason;
  final List<CiqualFood> foods;

  /// Quantité proposée à l'ajout (modifiable ensuite).
  final double grams;
}

/// Suggestions locales, transparentes et sans IA, à partir des totaux du repas.
/// Repères indicatifs pour un repas principal d'adulte, pas des recommandations médicales.
class MealSuggester {
  MealSuggester(this.index);

  final FoodIndex index;

  static const _proteins = ['lentille', 'œuf', 'poulet', 'thon', 'pois chiche'];
  static const _vegetables = ['brocoli', 'haricot vert', 'carotte', 'tomate', 'courgette'];
  static const _fruits = ['orange', 'kiwi', 'pomme', 'clémentine'];
  static const _starches = ['riz', 'pâtes', 'pain', 'pomme de terre'];

  List<MealSuggestion> suggest(List<MealItem> items) {
    if (items.isEmpty) return const [];
    final t = MealTotals(items);
    final present = {for (final i in items) if (i.ciqualCode != null) i.ciqualCode!};
    final out = <MealSuggestion>[];

    final hasVeg = items.any((i) => i.isFruitOrVegetable && !i.isFruit);
    final hasFruit = items.any((i) => i.isFruit);

    if (t.value('proteins') < 20) {
      out.add(MealSuggestion(
        title: 'Une source de protéines',
        reason: '${_g(t.value('proteins'))} g de protéines pour l\'instant.',
        foods: _resolve(_proteins, present),
        grams: 120,
      ));
    }
    if (!hasVeg) {
      out.add(MealSuggestion(
        title: 'Des légumes',
        reason: 'Aucun légume dans le repas.',
        foods: _resolve(_vegetables, present),
        grams: 150,
      ));
    } else if (t.value('fiber') < 7) {
      out.add(MealSuggestion(
        title: 'Plus de fibres',
        reason: '${_g(t.value('fiber'))} g de fibres pour l\'instant.',
        foods: _resolve(['lentille', 'pois chiche', 'haricot vert'], present),
        grams: 150,
      ));
    }
    if (t.value('kcal') < 350 && t.value('carbs') < 40) {
      out.add(MealSuggestion(
        title: 'Un féculent',
        reason: 'Repas encore léger (${t.value('kcal').round()} kcal).',
        foods: _resolve(_starches, present),
        grams: 150,
      ));
    }
    if (!hasFruit && t.vitaminC < 30) {
      out.add(MealSuggestion(
        title: 'Un fruit',
        reason: 'Peu de vitamine C (${t.vitaminC.round()} mg).',
        foods: _resolve(_fruits, present),
        grams: 150,
      ));
    }
    return out.where((s) => s.foods.isNotEmpty).toList();
  }

  List<CiqualFood> _resolve(List<String> names, Set<int> present) {
    final out = <CiqualFood>[];
    for (final name in names) {
      final c = FoodAliases.lookup(name);
      final food = index.bestMatch(c?.ciqualQuery ?? name, prefer: c?.prefer ?? PreferredState.any);
      if (food != null && !present.contains(food.code) && !out.any((f) => f.code == food.code)) out.add(food);
    }
    return out;
  }

  static String _g(double v) => v < 10 ? v.toStringAsFixed(1).replaceAll('.', ',') : v.round().toString();
}
