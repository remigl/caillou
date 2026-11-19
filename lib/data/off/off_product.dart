import '../../core/nutrients.dart';

/// Produit Open Food Facts, réduit à ce que l'app affiche.
class OffProduct {
  const OffProduct({
    required this.barcode,
    required this.nutrition,
    this.name,
    this.brand,
    this.quantity,
    this.imageUrl,
    this.category,
    this.ingredients,
    this.allergens = const [],
    this.traces = const [],
    this.labels = const [],
    this.nutriScore,
    this.nova,
    this.nutritionNotProvided = false,
  });

  final String barcode;
  final String? name;
  final String? brand;
  final String? quantity;
  final String? imageUrl;
  final String? category;
  final String? ingredients;
  final List<String> allergens;
  final List<String> traces;
  final List<String> labels;

  /// "a" à "e", ou null si non calculé / non applicable.
  final String? nutriScore;

  /// 1 à 4, ou null.
  final int? nova;
  final Nutrition nutrition;

  /// Le fabricant/contributeur a indiqué « pas d'informations nutritionnelles ».
  final bool nutritionNotProvided;

  String get displayName => name ?? 'Produit sans nom';

  /// Pour les boissons, Open Food Facts exprime en pratique les valeurs pour 100 ml.
  bool get isLiquid {
    final q = quantity?.toLowerCase() ?? '';
    return RegExp(r'\d\s*(ml|cl|dl|l)\b').hasMatch(q);
  }

  /// Champs demandés à l'API (réponse plus légère, cf. documentation Open Food Facts).
  static const List<String> apiFields = [
    'code',
    'product_name',
    'product_name_fr',
    'generic_name_fr',
    'brands',
    'quantity',
    'image_front_url',
    'image_front_small_url',
    'image_url',
    'categories',
    'ingredients_text',
    'ingredients_text_fr',
    'allergens_tags',
    'traces_tags',
    'labels',
    'nutriscore_grade',
    'nutrition_grades',
    'nova_group',
    'nutriments',
    'no_nutrition_data',
  ];

  factory OffProduct.fromJson(Map<String, dynamic> p, {required String barcode}) {
    final nutriments = p['nutriments'] is Map ? Map<String, dynamic>.from(p['nutriments'] as Map) : const <String, dynamic>{};
    NutrientValue n(String key) => NutrientValue.fromOff(nutriments['${key}_100g']);

    var kcal = n('energy-kcal');
    var kj = n('energy-kj');
    if (!kj.isAvailable) kj = n('energy'); // "energy_100g" est en kJ
    var energySource = EnergySource.direct;
    if (!kcal.isAvailable && kj.kind == NutrientKind.exact) {
      kcal = NutrientValue.exact(kj.value! / 4.184);
      energySource = EnergySource.convertedFromKj;
    }

    return OffProduct(
      barcode: (_str(p['code']) ?? barcode),
      name: _str(p['product_name_fr']) ?? _str(p['product_name']) ?? _str(p['generic_name_fr']),
      brand: _firstOfList(_str(p['brands'])),
      quantity: _str(p['quantity']),
      imageUrl: _str(p['image_front_url']) ?? _str(p['image_url']) ?? _str(p['image_front_small_url']),
      category: _lastOfList(_str(p['categories'])),
      ingredients: _str(p['ingredients_text_fr']) ?? _str(p['ingredients_text']),
      allergens: _tags(p['allergens_tags']).map(allergenLabel).toList(),
      traces: _tags(p['traces_tags']).map(allergenLabel).toList(),
      labels: _splitList(_str(p['labels'])).map(_stripLangPrefix).take(10).toList(),
      nutriScore: _grade(_str(p['nutriscore_grade']) ?? _str(p['nutrition_grades'])),
      nova: _nova(p['nova_group']),
      nutritionNotProvided: _str(p['no_nutrition_data']) == 'on',
      nutrition: Nutrition(
        energyKcal: kcal,
        energyKj: kj,
        fat: n('fat'),
        saturatedFat: n('saturated-fat'),
        carbohydrates: n('carbohydrates'),
        sugars: n('sugars'),
        fiber: n('fiber'),
        proteins: n('proteins'),
        salt: n('salt'),
        energySource: energySource,
      ),
    );
  }

  static String? _str(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static List<String> _splitList(String? s) =>
      s == null ? const [] : s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  static String? _firstOfList(String? s) {
    final l = _splitList(s);
    return l.isEmpty ? null : l.first;
  }

  static String? _lastOfList(String? s) {
    final l = _splitList(s);
    return l.isEmpty ? null : _stripLangPrefix(l.last);
  }

  static String _stripLangPrefix(String s) {
    final m = RegExp(r'^[a-z]{2}:\s*').firstMatch(s);
    final out = m == null ? s : s.substring(m.end);
    return out.isEmpty ? s : out[0].toUpperCase() + out.substring(1);
  }

  static List<String> _tags(Object? v) =>
      v is List ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [];

  static String? _grade(String? g) {
    if (g == null) return null;
    final l = g.toLowerCase();
    return const ['a', 'b', 'c', 'd', 'e'].contains(l) ? l : null;
  }

  static int? _nova(Object? v) {
    final i = v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
    return i != null && i >= 1 && i <= 4 ? i : null;
  }

  /// "en:gluten" -> "Gluten". Les 14 allergènes réglementaires (UE) sont traduits.
  static String allergenLabel(String tag) {
    const fr = {
      'gluten': 'Gluten',
      'milk': 'Lait',
      'eggs': 'Œufs',
      'nuts': 'Fruits à coque',
      'peanuts': 'Arachides',
      'soybeans': 'Soja',
      'fish': 'Poisson',
      'crustaceans': 'Crustacés',
      'molluscs': 'Mollusques',
      'celery': 'Céleri',
      'mustard': 'Moutarde',
      'sesame-seeds': 'Sésame',
      'sulphur-dioxide-and-sulphites': 'Sulfites',
      'lupin': 'Lupin',
    };
    final key = tag.contains(':') ? tag.substring(tag.indexOf(':') + 1) : tag;
    final known = fr[key];
    if (known != null) return known;
    final words = key.replaceAll('-', ' ');
    return words.isEmpty ? tag : words[0].toUpperCase() + words.substring(1);
  }
}
