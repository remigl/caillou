import '../../core/nutrients.dart';

/// Statut tiré de `ingredients_analysis_tags` : oui / non / peut-être / inconnu.
enum Tri { yes, no, maybe, unknown }

/// Nutriment supplémentaire d'Open Food Facts (vitamines, minéraux...), converti dans une unité lisible.
class ExtraNutrient {
  const ExtraNutrient(this.label, this.value, this.unit);
  final String label;
  final NutrientValue value;
  final String unit;
}

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
    this.additives = const [],
    this.vegan = Tri.unknown,
    this.vegetarian = Tri.unknown,
    this.palmOil = Tri.unknown,
    this.nutrientLevels = const {},
    this.environmentalGrade,
    this.co2PerKg,
    this.origins,
    this.manufacturingPlaces,
    this.categories = const [],
    this.ciqualCode,
    this.extraNutrients = const [],
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

  /// Codes additifs ("e330", "e150d").
  final List<String> additives;

  /// Sans produit animal / sans viande ni poisson / sans huile de palme : oui (yes), non (no)...
  /// Pour l'huile de palme : yes = contient, no = n'en contient pas.
  final Tri vegan;
  final Tri vegetarian;
  final Tri palmOil;

  /// Repères calculés par Open Food Facts : {"fat": "low", "sugars": "high", ...}.
  final Map<String, String> nutrientLevels;

  /// Score environnemental Open Food Facts ("a-plus", "a" ... "f").
  final String? environmentalGrade;

  /// Impact climat Agribalyse de la catégorie (kg CO₂e par kg de produit).
  final double? co2PerKg;
  final String? origins;
  final String? manufacturingPlaces;

  /// Catégories, de la plus générale à la plus précise.
  final List<String> categories;

  /// Code de l'aliment générique Ciqual associé à la catégorie par Open Food Facts.
  final int? ciqualCode;
  final List<ExtraNutrient> extraNutrients;

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
    'additives_tags',
    'ingredients_analysis_tags',
    'nutrient_levels',
    'environmental_score_grade',
    'environmental_score_data',
    'ecoscore_grade',
    'ecoscore_data',
    'origins',
    'manufacturing_places',
    'categories_properties',
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
      additives: _tags(p['additives_tags'])
          .map((t) => t.contains(':') ? t.substring(t.indexOf(':') + 1) : t)
          .map((t) => t.toLowerCase())
          .toList(),
      vegan: _analysis(p['ingredients_analysis_tags'], 'vegan'),
      vegetarian: _analysis(p['ingredients_analysis_tags'], 'vegetarian'),
      palmOil: _palmOil(p['ingredients_analysis_tags']),
      nutrientLevels: _levels(p['nutrient_levels']),
      environmentalGrade: _envGrade(_str(p['environmental_score_grade']) ?? _str(p['ecoscore_grade'])),
      co2PerKg: _co2(p['environmental_score_data']) ?? _co2(p['ecoscore_data']),
      origins: _cleanList(_str(p['origins'])),
      manufacturingPlaces: _cleanList(_str(p['manufacturing_places'])),
      categories: _splitList(_str(p['categories'])).map(_stripLangPrefix).toList(),
      ciqualCode: _ciqualCode(p['categories_properties']),
      extraNutrients: _extras(nutriments),
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

  static Tri _analysis(Object? tags, String what) {
    final l = _tags(tags);
    if (l.contains('en:$what')) return Tri.yes;
    if (l.contains('en:non-$what')) return Tri.no;
    if (l.contains('en:maybe-$what')) return Tri.maybe;
    return Tri.unknown;
  }

  static Tri _palmOil(Object? tags) {
    final l = _tags(tags);
    if (l.contains('en:palm-oil')) return Tri.yes;
    if (l.contains('en:palm-oil-free')) return Tri.no;
    if (l.contains('en:may-contain-palm-oil')) return Tri.maybe;
    return Tri.unknown;
  }

  static Map<String, String> _levels(Object? v) {
    if (v is! Map) return const {};
    final out = <String, String>{};
    v.forEach((k, val) {
      if (k is String && (val == 'low' || val == 'moderate' || val == 'high')) out[k] = val as String;
    });
    return out;
  }

  static String? _envGrade(String? g) {
    if (g == null) return null;
    final l = g.toLowerCase();
    return const ['a-plus', 'a', 'b', 'c', 'd', 'e', 'f'].contains(l) ? l : null;
  }

  static double? _co2(Object? data) {
    if (data is! Map) return null;
    final agb = data['agribalyse'];
    if (agb is! Map) return null;
    final v = agb['co2_total'];
    final d = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    return d != null && d.isFinite && d > 0 ? d : null;
  }

  static String? _cleanList(String? s) {
    final l = _splitList(s).map(_stripLangPrefix).toList();
    return l.isEmpty ? null : l.join(', ');
  }

  static int? _ciqualCode(Object? props) {
    if (props is! Map) return null;
    for (final key in const ['ciqual_food_code:en', 'agribalyse_food_code:en']) {
      final v = props[key];
      final i = v is num ? v.toInt() : int.tryParse(v?.toString().trim() ?? '');
      if (i != null && i > 0) return i;
    }
    return null;
  }

  /// Nutriments supplémentaires. Open Food Facts stocke `xxx_100g` en grammes : conversion en mg / µg.
  static const List<(String, String, String, double)> _extraDefs = [
    ('starch', 'Amidon', 'g', 1),
    ('polyols', 'Polyols', 'g', 1),
    ('monounsaturated-fat', 'Acides gras monoinsaturés', 'g', 1),
    ('polyunsaturated-fat', 'Acides gras polyinsaturés', 'g', 1),
    ('omega-3-fat', 'Oméga-3', 'g', 1),
    ('omega-6-fat', 'Oméga-6', 'g', 1),
    ('trans-fat', 'Acides gras trans', 'g', 1),
    ('cholesterol', 'Cholestérol', 'mg', 1000),
    ('sodium', 'Sodium', 'mg', 1000),
    ('potassium', 'Potassium', 'mg', 1000),
    ('calcium', 'Calcium', 'mg', 1000),
    ('magnesium', 'Magnésium', 'mg', 1000),
    ('phosphorus', 'Phosphore', 'mg', 1000),
    ('iron', 'Fer', 'mg', 1000),
    ('zinc', 'Zinc', 'mg', 1000),
    ('iodine', 'Iode', 'µg', 1000000),
    ('selenium', 'Sélénium', 'µg', 1000000),
    ('vitamin-a', 'Vitamine A', 'µg', 1000000),
    ('vitamin-d', 'Vitamine D', 'µg', 1000000),
    ('vitamin-e', 'Vitamine E', 'mg', 1000),
    ('vitamin-k', 'Vitamine K', 'µg', 1000000),
    ('vitamin-c', 'Vitamine C', 'mg', 1000),
    ('vitamin-b1', 'Vitamine B1', 'mg', 1000),
    ('vitamin-b2', 'Vitamine B2', 'mg', 1000),
    ('vitamin-pp', 'Vitamine B3 (PP)', 'mg', 1000),
    ('vitamin-b6', 'Vitamine B6', 'mg', 1000),
    ('vitamin-b9', 'Vitamine B9 (folates)', 'µg', 1000000),
    ('vitamin-b12', 'Vitamine B12', 'µg', 1000000),
    ('caffeine', 'Caféine', 'mg', 1000),
  ];

  static List<ExtraNutrient> _extras(Map<String, dynamic> nutriments) {
    final out = <ExtraNutrient>[];
    for (final (key, label, unit, factor) in _extraDefs) {
      final v = NutrientValue.fromOff(nutriments['${key}_100g']);
      if (v.kind != NutrientKind.exact) continue;
      out.add(ExtraNutrient(label, NutrientValue.exact(v.value! * factor), unit));
    }
    final alcohol = NutrientValue.fromOff(nutriments['alcohol_100g']);
    if (alcohol.kind == NutrientKind.exact && alcohol.value! > 0) out.add(ExtraNutrient('Alcool', alcohol, '% vol'));
    final fruits = NutrientValue.fromOff(nutriments['fruits-vegetables-nuts-estimate-from-ingredients_100g']);
    if (fruits.kind == NutrientKind.exact) {
      out.add(ExtraNutrient('Fruits, légumes, légumineuses (estimation)', fruits, '%'));
    }
    return out;
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
