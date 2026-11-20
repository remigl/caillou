import 'dart:convert';

import 'package:flutter/services.dart';

/// Acides aminés d'un aliment comparable USDA (SR Legacy, domaine public), en g / 100 g.
class AminoProfile {
  const AminoProfile({required this.usdaName, required this.values});

  /// Nom USDA de l'aliment rapproché (affiché pour la transparence).
  final String usdaName;

  /// (libellé, essentiel, valeur) ; valeurs absentes exclues.
  final List<(String, bool, double)> values;
}

class AminoDatabase {
  AminoDatabase({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  Future<Map<String, dynamic>?>? _loading;

  Future<Map<String, dynamic>?> _load() => _loading ??= () async {
        try {
          return jsonDecode(await _bundle.loadString('assets/data/amino.json', cache: false)) as Map<String, dynamic>;
        } catch (_) {
          return null;
        }
      }();

  /// Profil pour un code Ciqual, ou null si aucun aliment USDA ne correspond assez bien.
  Future<AminoProfile?> forCiqual(int code) async {
    final data = await _load();
    if (data == null) return null;
    return parseAmino(data, code);
  }
}

AminoProfile? parseAmino(Map<String, dynamic> data, int code) {
  final mapping = data['ciqual'];
  final usda = data['usda'];
  final names = data['names'];
  final essential = data['essential'];
  if (mapping is! Map || usda is! List || names is! List) return null;
  final idx = mapping['$code'];
  if (idx is! num || idx < 0 || idx >= usda.length) return null;
  final food = usda[idx.toInt()];
  if (food is! Map || food['v'] is! List) return null;
  final v = food['v'] as List;
  final values = <(String, bool, double)>[];
  for (var i = 0; i < names.length && i < v.length; i++) {
    final x = v[i];
    if (x is num) {
      final isEssential = essential is List && i < essential.length && essential[i] == true;
      values.add((names[i].toString(), isEssential, x.toDouble()));
    }
  }
  if (values.isEmpty) return null;
  return AminoProfile(usdaName: food['d']?.toString() ?? '', values: values);
}
