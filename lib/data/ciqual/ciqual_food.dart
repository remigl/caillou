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
  })  : tokens = tokenize(name),
        tokensEn = nameEn == null ? const [] : tokenize(nameEn),
        firstSegmentKey = phraseKey(name.split(',').first) {
    states = _detectStates(tokens);
  }

  final int code;
  final String name;
  final String? nameEn;

  /// Sous-groupe Ciqual ("fruits", "légumes", "pâtes, riz et céréales"...).
  final String? group;
  final Nutrition nutrition;

  /// Jetons normalisés du nom français (sans accents, pluriels simples retirés).
  final List<String> tokens;
  final List<String> tokensEn;

  /// "Brocoli, cru" -> "brocoli". Sert à regrouper les variantes cru / cuit / surgelé.
  final String firstSegmentKey;
  late final Set<FoodState> states;

  static Set<FoodState> _detectStates(List<String> tokens) {
    final s = <FoodState>{};
    for (final t in tokens) {
      if (t == 'cru' || t == 'crue' || t == 'crus') s.add(FoodState.raw);
      if (t == 'cuit' || t == 'cuite' || t.startsWith('bouilli') || t == 'vapeur' ||
          t.startsWith('grille') || t.startsWith('roti') || t.startsWith('poele') ||
          t == 'frit' || t == 'frite') {
        s.add(FoodState.cooked);
      }
      if (t.startsWith('surgel')) s.add(FoodState.frozen);
      if (t.startsWith('apperti') || t == 'conserve') s.add(FoodState.canned);
      if (t.startsWith('seche') || t == 'sec' || t.startsWith('deshydrate')) s.add(FoodState.dried);
    }
    return s;
  }
}

class CiqualDataset {
  const CiqualDataset({required this.foods, required this.source, required this.licence, required this.version});

  final List<CiqualFood> foods;
  final String source;
  final String licence;
  final String version;
}

/// Parse l'asset généré par tool/build_ciqual.mjs. Fonction de premier niveau pour `compute`.
CiqualDataset parseCiqualJson(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final keys = (json['nutrients'] as List).cast<String>();
  final index = {for (var i = 0; i < keys.length; i++) keys[i]: i};
  final foods = <CiqualFood>[];

  for (final item in json['foods'] as List) {
    final m = item as Map<String, dynamic>;
    final v = m['v'] as List;
    NutrientValue at(String key) {
      final i = index[key];
      if (i == null || i >= v.length) return NutrientValue.missing;
      return NutrientValue.fromCiqual(v[i]);
    }

    foods.add(CiqualFood(
      code: (m['c'] as num).toInt(),
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
  );
}
