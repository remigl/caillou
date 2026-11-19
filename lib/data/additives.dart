import 'dart:convert';

import 'package:flutter/services.dart';

/// Additif décrit pour l'affichage : "E330", "Acide citrique", "Acidifiant".
class AdditiveInfo {
  const AdditiveInfo(this.code, this.name, this.role);
  final String code;
  final String? name;
  final String? role;
}

/// Noms des additifs (taxonomie Open Food Facts, ODbL), embarqués et chargés à la demande.
/// Si la table est absente, seuls les codes E sont affichés.
class AdditiveDatabase {
  AdditiveDatabase({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  Future<Map<String, List<String>>>? _loading;

  Future<Map<String, List<String>>> _load() => _loading ??= () async {
        try {
          final raw = await _bundle.loadString('assets/data/additives.json', cache: false);
          final json = jsonDecode(raw) as Map<String, dynamic>;
          final table = json['additives'] as Map<String, dynamic>;
          return {
            for (final e in table.entries)
              if (e.value is List) e.key: (e.value as List).map((x) => x.toString()).toList(),
          };
        } catch (_) {
          return const <String, List<String>>{};
        }
      }();

  Future<List<AdditiveInfo>> describe(List<String> codes) async {
    final table = await _load();
    return [
      for (final c in codes)
        AdditiveInfo(
          formatCode(c),
          table[c]?.isNotEmpty == true ? table[c]![0] : null,
          (table[c]?.length ?? 0) > 1 ? table[c]![1] : null,
        ),
    ];
  }

  /// "e150d" -> "E150d".
  static String formatCode(String code) =>
      code.isEmpty ? code : code[0].toUpperCase() + code.substring(1);
}
