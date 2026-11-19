import 'ciqual/ciqual_food.dart';
import 'ciqual/food_index.dart';
import 'off/off_product.dart';

/// Croisement Open Food Facts -> Ciqual : l'aliment générique comparable à un produit emballé.
///
/// 1. Code Ciqual associé à la catégorie par Open Food Facts (`categories_properties`).
/// 2. Sinon, la catégorie la plus précise dont le nom correspond nettement à un aliment Ciqual.
CiqualFood? genericEquivalent(OffProduct product, FoodIndex index) {
  final code = product.ciqualCode;
  if (code != null) {
    final byCode = index.byCode(code);
    if (byCode != null) return byCode;
  }
  for (final category in product.categories.reversed.take(4)) {
    final best = index.searchScored(category, limit: 1);
    // 110 : le début du nom Ciqual correspond exactement à la catégorie ("Spaghetti" ≠ "Pâtes...").
    if (best.isNotEmpty && best.first.score >= 110) return best.first.food;
  }
  return null;
}
