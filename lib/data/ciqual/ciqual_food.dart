import 'dart:convert';

import '../../core/nutrients.dart';
import '../../core/text.dart';

/// État de préparation détecté dans le nom Ciqual ("Brocoli, cru", "Riz blanc, cuit").
enum FoodState {
  raw('Cru'),
  cooked('Cuit'),
  frozen('Surgelé'),
  canned('Conserve'),
  dried('Séché');

  const FoodState(this.label);
  final String label;
}

/// Un aliment générique de la table Ciqual, valeurs pour 100 g de partie comestible.
class CiqualFood {
  CiqualFood({
    required this.code,
    required this.name,
    required this.nutrition,
    this.nameEn,
    this.group,
    this.details = const [],
  })  : tokens = tokenize(_searchName(name)),
        tokensEn = nameEn == null ? const [] : tokenize(nameEn),
        firstSegmentKey = phraseKey(_searchName(name).split(',').first) {
    final laterSegments = tokenize(_searchName(name).split(',').skip(1).join(' '));
    states = _detectStates(tokens, laterSegments);
    rankBonus = _rankBonus();
  }

  /// "Tomate sans précision, crue (aliment moyen)" -> "Tomate , crue" pour la recherche.
  static String _searchName(String name) => name
      .replaceAll(RegExp(r'\(aliment moyen\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'sans pr[ée]cision', caseSensitive: false), '');

  final int code;
  final String name;
  final String? nameEn;

  /// Sous-groupe Ciqual ("fruits", "légumes", "pâtes, riz et céréales"...).
  final String? group;
  final Nutrition nutrition;

  /// Composition détaillée : (index dans [CiqualDataset.detailDefs], valeur). Seules les valeurs connues.
  final List<(int, NutrientValue)> details;

  /// Jetons normalisés du nom français (sans accents, pluriels simples retirés).
  final List<String> tokens;
  final List<String> tokensEn;

  /// "Brocoli, cru" -> "brocoli". Sert à regrouper les variantes cru / cuit / surgelé.
  final String firstSegmentKey;
  late final Set<FoodState> states;

  /// Bonus de classement propre à l'aliment : favorise les fiches « aliment moyen »,
  /// pénalise les échantillons régionaux, les formes séchées / en conserve et l'énergie absente.
  late final double rankBonus;

  double _rankBonus() {
    final n = tokens.join(' ');
    var b = 0.0;
    if (name.toLowerCase().contains('aliment moyen')) b += 12;
    if (n.contains('preleve')) b -= 25;
    if (RegExp(r'\b(preemballe|artisanal|fait maison|bio|label rouge)').hasMatch(n)) b -= 6;
    if (!nutrition.energyKcal.isAvailable) b -= 30;
    if (states.contains(FoodState.canned)) b -= 40;
    if (states.contains(FoodState.dried)) b -= 25;
    if (states.contains(FoodState.frozen)) b -= 10;
    if (states.contains(FoodState.raw) || states.contains(FoodState.cooked)) b += 4;
    return b;
  }

  /// [later] : jetons après la première virgule. « Pâtes sèches » n'est pas un aliment séché,
  /// « Pomme, sèche » l'est.
  static Set<FoodState> _detectStates(List<String> tokens, List<String> later) {
    final s = <FoodState>{};
    for (final t in tokens) {
      if (t == 'cru' || t == 'crue' || t == 'crus') s.add(FoodState.raw);
      if (t == 'cuit' || t == 'cuite' || t.startsWith('bouilli') || t == 'vapeur' ||
          t.startsWith('grille') || t.startsWith('roti') || t.startsWith('poele') ||
          t == 'frit' || t == 'frite' || (tokens.first == 'oeuf' && (t == 'dur' || t == 'coque' || t == 'poche')) ||
          t.startsWith('brouille')) {
        s.add(FoodState.cooked);
      }
      if (t.startsWith('surgel')) s.add(FoodState.frozen);
      if (t.startsWith('apperti') || t == 'conserve') s.add(FoodState.canned);
    }
    for (final t in later) {
      if (t.startsWith('seche') || t == 'sec' || t.startsWith('deshydrate') || t == 'poudre') {
        s.add(FoodState.dried);
      }
    }
    return s;
  }
}

/// Constituant de la composition détaillée ("Vitamine C", "mg", "Vitamines").
class DetailDef {
  const DetailDef(this.name, this.unit, this.group);
  final String name;
  final String unit;
  final String group;
}

class CiqualDataset {
  const CiqualDataset({
    required this.foods,
    required this.source,
    required this.licence,
    required this.version,
    this.detailDefs = const [],
  });

  final List<CiqualFood> foods;
  final List<DetailDef> detailDefs;
  final String source;
  final String licence;
  final String version;
}

/// Parse l'asset généré par tool/build_ciqual.mjs. Fonction de premier niveau pour `compute`.
CiqualDataset parseCiqualJson(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final keys = (json['nutrients'] as List).cast<String>();
  final index = {for (var i = 0; i < keys.length; i++) keys[i]: i};
  final defs = <DetailDef>[
    for (final d in (json['details'] as List? ?? const []))
      if (d is Map) DetailDef(d['n'] as String? ?? '', d['u'] as String? ?? '', d['g'] as String? ?? 'Autres'),
  ];
  final foods = <CiqualFood>[];

  for (final item in json['foods'] as List) {
    final m = item as Map<String, dynamic>;
    final v = m['v'] as List;
    NutrientValue at(String key) {
      final i = index[key];
      if (i == null || i >= v.length) return NutrientValue.missing;
      return NutrientValue.fromCiqual(v[i]);
    }

    final details = <(int, NutrientValue)>[];
    final d = m['d'];
    if (d is List) {
      for (var i = 0; i + 1 < d.length; i += 2) {
        final di = d[i];
        if (di is num && di >= 0 && di < defs.length) {
          final value = NutrientValue.fromCiqual(d[i + 1]);
          if (value.isAvailable) details.add((di.toInt(), value));
        }
      }
    }

    foods.add(CiqualFood(
      code: (m['c'] as num).toInt(),
      details: details,
      name: m['n'] as String,
      nameEn: m['e'] as String?,
      group: m['g'] as String?,
      nutrition: Nutrition(
        energyKcal: at('kcal'),
        energyKj: at('kj'),
        fat: at('fat'),
        saturatedFat: at('satFat'),
        carbohydrates: at('carbs'),
        sugars: at('sugars'),
        fiber: at('fiber'),
        proteins: at('proteins'),
        salt: at('salt'),
        energySource: m['ef'] == 1 ? EnergySource.ciqualJones : EnergySource.direct,
      ),
    ));
  }

  return CiqualDataset(
    foods: foods,
    source: json['source'] as String? ?? 'Anses, table Ciqual',
    licence: json['licence'] as String? ?? 'Licence Ouverte 2.0',
    version: json['version'] as String? ?? '',
    detailDefs: defs,
  );
}
