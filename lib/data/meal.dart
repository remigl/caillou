import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/nutrients.dart';
import 'ciqual/ciqual_food.dart';
import 'off/off_product.dart';

/// Un élément du repas : un aliment ou un produit, avec une quantité choisie par l'utilisateur.
/// Les valeurs pour 100 g sont copiées : le repas reste consultable hors ligne.
class MealItem {
  MealItem({
    required this.key,
    required this.name,
    required this.per100,
    required this.grams,
    this.ciqualCode,
    this.group,
    this.vitaminCPer100,
    this.isProduct = false,
  });

  /// "ciqual:20057" ou "off:3017620422003".
  final String key;
  final String name;
  final Nutrition per100;
  double grams;
  final int? ciqualCode;

  /// Sous-groupe Ciqual ("légumes", "fruits"...) quand il est connu.
  final String? group;

  /// Vitamine C (mg / 100 g) si connue, pour la suggestion « fruit ».
  final double? vitaminCPer100;
  final bool isProduct;

  factory MealItem.fromFood(CiqualFood food, List<DetailDef> defs, {double grams = 100}) {
    double? vitC;
    for (final (i, v) in food.details) {
      if (i < defs.length && defs[i].name == 'Vitamine C' && v.kind == NutrientKind.exact) vitC = v.value;
    }
    return MealItem(
      key: 'ciqual:${food.code}',
      name: food.name,
      per100: food.nutrition,
      grams: grams,
      ciqualCode: food.code,
      group: food.group,
      vitaminCPer100: vitC,
    );
  }

  factory MealItem.fromProduct(OffProduct p, {CiqualFood? generic, double grams = 100}) => MealItem(
        key: 'off:${p.barcode}',
        name: [p.displayName, if (p.brand != null) p.brand!].join(' — '),
        per100: p.nutrition,
        grams: grams,
        group: generic?.group,
        isProduct: true,
      );

  Map<String, dynamic> toJson() => {
        'k': key,
        'n': name,
        'g': grams,
        'p': per100.toJson(),
        if (ciqualCode != null) 'c': ciqualCode,
        if (group != null) 'gr': group,
        if (vitaminCPer100 != null) 'vc': vitaminCPer100,
        if (isProduct) 'off': true,
      };

  static MealItem? fromJson(Object? raw) {
    if (raw is! Map || raw['k'] is! String || raw['n'] is! String) return null;
    return MealItem(
      key: raw['k'] as String,
      name: raw['n'] as String,
      grams: (raw['g'] as num?)?.toDouble() ?? 100.0,
      per100: Nutrition.fromJson(raw['p']),
      ciqualCode: (raw['c'] as num?)?.toInt(),
      group: raw['gr'] as String?,
      vitaminCPer100: (raw['vc'] as num?)?.toDouble(),
      isProduct: raw['off'] == true,
    );
  }

  bool get isFruitOrVegetable {
    final g = (group ?? '').toLowerCase();
    return (g.contains('légume') || g.contains('fruit') || g.contains('salade')) && !g.contains('coque');
  }

  bool get isFruit => (group ?? '').toLowerCase().startsWith('fruit') && !(group ?? '').contains('coque');
}

/// Totaux du repas. Une valeur manquante pour un élément rend le total incomplet (signalé),
/// « traces » et « < x » comptent pour 0.
class MealTotals {
  MealTotals(this.items) {
    final total = <String, double>{};
    final incomplete = <String, Set<String>>{};
    void add(String key, NutrientValue v, MealItem item) {
      total.putIfAbsent(key, () => 0);
      if (v.kind == NutrientKind.exact) {
        total[key] = total[key]! + v.value! * item.grams / 100;
      } else if (v.kind == NutrientKind.missing) {
        incomplete.putIfAbsent(key, () => {}).add(item.name);
      }
    }

    for (final i in items) {
      final n = i.per100;
      add('kcal', n.energyKcal, i);
      add('kj', n.energyKj, i);
      add('fat', n.fat, i);
      add('satFat', n.saturatedFat, i);
      add('carbs', n.carbohydrates, i);
      add('sugars', n.sugars, i);
      add('fiber', n.fiber, i);
      add('proteins', n.proteins, i);
      add('salt', n.salt, i);
      if (i.vitaminCPer100 != null) vitaminC += i.vitaminCPer100! * i.grams / 100;
    }
    _total = total;
    missingFor = incomplete;
  }

  final List<MealItem> items;
  late final Map<String, double> _total;

  /// Nutriment -> éléments pour lesquels la valeur manque.
  late final Map<String, Set<String>> missingFor;
  double vitaminC = 0;

  double get grams => items.fold<double>(0.0, (s, i) => s + i.grams);
  double value(String key) => _total[key] ?? 0;

  NutrientValue _v(String key) {
    // Aucun élément ne fournit la valeur : « non disponible » plutôt que 0.
    if (items.isEmpty || (missingFor[key]?.length ?? 0) == items.length) return NutrientValue.missing;
    return NutrientValue.exact(value(key));
  }

  Nutrition get nutrition => Nutrition(
        energyKcal: _v('kcal'),
        energyKj: _v('kj'),
        fat: _v('fat'),
        saturatedFat: _v('satFat'),
        carbohydrates: _v('carbs'),
        sugars: _v('sugars'),
        fiber: _v('fiber'),
        proteins: _v('proteins'),
        salt: _v('salt'),
      );

  bool get isIncomplete => missingFor.entries.any((e) => e.key != 'kj' && e.value.isNotEmpty);

  /// Éléments sans valeur pour au moins un nutriment (hors kJ).
  Set<String> get incompleteItems => {
        for (final e in missingFor.entries)
          if (e.key != 'kj') ...e.value,
      };
}

/// Repas en cours, enregistré sur le téléphone.
class MealStore extends ValueNotifier<List<MealItem>> {
  MealStore(this._prefs) : super(const []) {
    value = _load();
  }

  final SharedPreferences _prefs;
  static const _key = 'meal.v1';

  List<MealItem> _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).map(MealItem.fromJson).whereType<MealItem>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(List<MealItem> items) async {
    value = List.unmodifiable(items);
    await _prefs.setString(_key, jsonEncode([for (final i in items) i.toJson()]));
  }

  bool contains(String key) => value.any((i) => i.key == key);

  /// Ajoute l'élément ; s'il est déjà présent, ajoute la quantité.
  Future<void> add(MealItem item) {
    final items = [...value];
    final existing = items.indexWhere((i) => i.key == item.key);
    if (existing >= 0) {
      items[existing].grams += item.grams;
    } else {
      items.add(item);
    }
    return _save(items);
  }

  Future<void> setGrams(String key, double grams) {
    final items = [...value];
    for (final i in items) {
      if (i.key == key) i.grams = grams;
    }
    return _save(items);
  }

  Future<void> remove(String key) => _save(value.where((i) => i.key != key).toList());

  Future<void> clear() => _save(const []);
}
