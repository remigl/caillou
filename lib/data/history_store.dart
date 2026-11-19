import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum HistoryKind { product, food }

/// Un élément récemment consulté (produit scanné ou aliment Ciqual).
class HistoryEntry {
  const HistoryEntry({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle,
    this.kcal,
    required this.at,
  });

  final HistoryKind kind;

  /// Code-barres (produit) ou code Ciqual (aliment).
  final String id;
  final String title;
  final String? subtitle;
  final String? kcal;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'k': kind.name,
        'id': id,
        't': title,
        if (subtitle != null) 's': subtitle,
        if (kcal != null) 'e': kcal,
        'at': at.millisecondsSinceEpoch,
      };

  static HistoryEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = HistoryKind.values.where((k) => k.name == raw['k']).firstOrNull;
    final id = raw['id'];
    final title = raw['t'];
    final at = raw['at'];
    if (kind == null || id is! String || title is! String || at is! num) return null;
    return HistoryEntry(
      kind: kind,
      id: id,
      title: title,
      subtitle: raw['s'] as String?,
      kcal: raw['e'] as String?,
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
    );
  }
}

class HistoryStore {
  HistoryStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'history.v1';
  static const maxEntries = 20;

  List<HistoryEntry> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map(HistoryEntry.fromJson).whereType<HistoryEntry>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(HistoryEntry entry) async {
    final list = load().where((e) => !(e.kind == entry.kind && e.id == entry.id)).toList()
      ..insert(0, entry);
    final trimmed = list.take(maxEntries).map((e) => e.toJson()).toList();
    await _prefs.setString(_key, jsonEncode(trimmed));
  }

  Future<void> clear() => _prefs.remove(_key);
}
