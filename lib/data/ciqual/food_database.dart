import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ciqual_food.dart';
import 'food_index.dart';

const String kCiqualAsset = 'assets/data/ciqual.json';

/// La base Ciqual n'a pas été générée (voir tool/build_ciqual.mjs).
class FoodDatabaseMissing implements Exception {
  const FoodDatabaseMissing();
  @override
  String toString() =>
      'Base d\'aliments absente. Générez-la avec : node tool/build_ciqual.mjs';
}

/// Chargement paresseux et unique de la table Ciqual embarquée dans l'app.
class FoodDatabase {
  FoodDatabase({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  Future<FoodIndex>? _loading;
  FoodIndex? _index;

  /// Disponible immédiatement si déjà chargée.
  FoodIndex? get loaded => _index;

  Future<FoodIndex> load() => _loading ??= _load();

  Future<FoodIndex> _load() async {
    final String raw;
    try {
      raw = await _bundle.loadString(kCiqualAsset, cache: false);
    } catch (_) {
      _loading = null;
      throw const FoodDatabaseMissing();
    }
    final dataset = await compute(parseCiqualJson, raw);
    return _index = FoodIndex(dataset);
  }
}
