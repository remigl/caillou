import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// Un rappel officiel de produit (retrait / rappel conso).
class ProductRecall {
  const ProductRecall({
    required this.source,
    required this.title,
    this.reason,
    this.risks,
    this.advice,
    this.date,
    this.url,
  });

  /// "RappelConso (France)" ou "FDA (États-Unis)".
  final String source;
  final String title;
  final String? reason;
  final String? risks;
  final String? advice;
  final DateTime? date;
  final String? url;
}

/// Recherche des rappels officiels pour un code-barres :
/// - RappelConso (DGCCRF / DGAL, Licence Ouverte) : jeu « RappelConso V2 produits triés par GTIN » ;
/// - openFDA food enforcement (domaine public) pour les codes UPC nord-américains.
/// Toute erreur réseau renvoie une liste vide (l'absence d'alerte n'est jamais affichée comme une garantie).
class RecallService {
  RecallService(this._client);

  final http.Client _client;
  final Map<String, Future<List<ProductRecall>>> _cache = {};

  static const rappelConsoBase =
      'https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/rappelconso-v2-gtin-trie/records';

  Future<List<ProductRecall>> forBarcode(String barcode) =>
      _cache.putIfAbsent(barcode, () async {
        final results = await Future.wait([_rappelConso(barcode), _openFda(barcode)]);
        return [...results[0], ...results[1]];
      });

  Future<List<ProductRecall>> _rappelConso(String barcode) async {
    try {
      // Recherche plein texte sur le code (sans dépendre du nom exact du champ GTIN),
      // puis vérification que l'enregistrement contient bien ce code.
      final uri = Uri.parse(rappelConsoBase).replace(queryParameters: {
        'where': '"$barcode"',
        'limit': '10',
      });
      final res = await _client.get(uri, headers: {'User-Agent': AppConfig.userAgent}).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const [];
      return parseRappelConso(jsonDecode(utf8.decode(res.bodyBytes)), barcode);
    } catch (_) {
      return const [];
    }
  }

  Future<List<ProductRecall>> _openFda(String barcode) async {
    final upc = northAmericanUpc(barcode);
    if (upc == null) return const [];
    try {
      final uri = Uri.parse('https://api.fda.gov/food/enforcement.json').replace(queryParameters: {
        'search': 'code_info:"$upc"',
        'limit': '5',
      });
      final res = await _client.get(uri, headers: {'User-Agent': AppConfig.userAgent}).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const []; // 404 = aucun résultat
      return parseOpenFda(jsonDecode(utf8.decode(res.bodyBytes)), upc);
    } catch (_) {
      return const [];
    }
  }
}

/// UPC-A (12 chiffres) pour les codes GS1 États-Unis / Canada (préfixes 000-139), sinon null.
String? northAmericanUpc(String barcode) {
  var code = barcode;
  if (code.length == 13 && code.startsWith('0')) code = code.substring(1);
  if (code.length != 12) return null;
  final prefix = int.tryParse(code.substring(0, 2)) ?? 99;
  return prefix <= 13 ? code : null;
}

String? _first(Map m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    if (v is List && v.isNotEmpty && v.first is String && (v.first as String).trim().isNotEmpty) {
      return (v.first as String).trim();
    }
  }
  return null;
}

/// Réponse explore v2.1 : {"total_count": n, "results": [{...}]}. Champs lus avec plusieurs noms possibles.
List<ProductRecall> parseRappelConso(Object? json, String barcode) {
  final results = json is Map ? json['results'] : null;
  if (results is! List) return const [];
  final out = <ProductRecall>[];
  final seen = <String>{};
  for (final r in results) {
    if (r is! Map) continue;
    // Garde-fou : le code doit apparaître dans l'enregistrement (évite les faux positifs du plein texte).
    if (!jsonEncode(r).contains(barcode)) continue;
    final id = _first(r, ['id', 'numero_fiche', 'reference_fiche', 'rappel_guid']) ?? '${out.length}';
    if (!seen.add(id)) continue;
    final name = _first(r, ['libelle', 'noms_des_modeles_ou_references', 'modeles_ou_references', 'nom_du_produit']);
    final brand = _first(r, ['marque_produit', 'nom_de_la_marque_du_produit', 'marque']);
    out.add(ProductRecall(
      source: 'RappelConso (France)',
      title: [if (name != null) name, if (brand != null && !(name ?? '').contains(brand)) brand].join(' — ').ifEmpty('Produit rappelé'),
      reason: _first(r, ['motif_rappel', 'motif_du_rappel']),
      risks: _first(r, ['risques_encourus', 'risques_encourus_par_le_consommateur']),
      advice: _first(r, ['conduites_a_tenir_par_le_consommateur', 'preconisations_sanitaires']),
      date: DateTime.tryParse(_first(r, ['date_publication', 'date_de_publication']) ?? ''),
      url: _first(r, ['lien_vers_la_fiche_rappel', 'lien_vers_la_fiche']),
    ));
  }
  return out;
}

/// Réponse openFDA : {"results": [{product_description, reason_for_recall, classification, recall_initiation_date}]}.
List<ProductRecall> parseOpenFda(Object? json, String upc) {
  final results = json is Map ? json['results'] : null;
  if (results is! List) return const [];
  final out = <ProductRecall>[];
  for (final r in results) {
    if (r is! Map) continue;
    final code = '${r['code_info'] ?? ''} ${r['product_description'] ?? ''}';
    if (!code.contains(upc)) continue;
    final d = r['recall_initiation_date']?.toString() ?? '';
    final date = d.length == 8 ? DateTime.tryParse('${d.substring(0, 4)}-${d.substring(4, 6)}-${d.substring(6)}') : null;
    out.add(ProductRecall(
      source: 'FDA (États-Unis)',
      title: (_first(r, ['product_description']) ?? 'Produit rappelé'),
      reason: _first(r, ['reason_for_recall']),
      risks: _first(r, ['classification']),
      advice: _first(r, ['status']),
      date: date,
    ));
  }
  return out;
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
