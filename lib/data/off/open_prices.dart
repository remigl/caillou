import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';

/// Un prix relevé par un contributeur d'Open Prices (projet Open Food Facts, ODbL).
class PriceObservation {
  const PriceObservation({
    required this.price,
    required this.currency,
    this.date,
    this.place,
    this.perKilo = false,
    this.discounted = false,
  });

  final double price;
  final String currency;
  final DateTime? date;
  final String? place;
  final bool perKilo;
  final bool discounted;
}

/// Client minimal d'Open Prices. Toute erreur renvoie une liste vide : la section est alors masquée.
class OpenPricesApi {
  OpenPricesApi(this._client, {this.baseUrl = 'https://prices.openfoodfacts.org'});

  final http.Client _client;
  final String baseUrl;
  final Map<String, Future<List<PriceObservation>>> _cache = {};

  /// Mis en cache pour la session : une seule requête par produit.
  Future<List<PriceObservation>> latest(String barcode, {int count = 5}) =>
      _cache.putIfAbsent(barcode, () => _fetch(barcode, count));

  Future<List<PriceObservation>> _fetch(String barcode, int count) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/prices').replace(queryParameters: {
        'product_code': barcode,
        'order_by': '-date',
        'size': '$count',
      });
      final res = await _client.get(uri, headers: {
        'User-Agent': AppConfig.userAgent,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const [];
      return parsePrices(jsonDecode(utf8.decode(res.bodyBytes)));
    } catch (_) {
      return const [];
    }
  }
}

/// Parsing tolérant de la réponse `{"items": [...]}`.
List<PriceObservation> parsePrices(Object? json) {
  final items = json is Map ? json['items'] : json;
  if (items is! List) return const [];
  final out = <PriceObservation>[];
  for (final it in items) {
    if (it is! Map) continue;
    final p = it['price'];
    final price = p is num ? p.toDouble() : double.tryParse(p?.toString() ?? '');
    final currency = it['currency']?.toString();
    if (price == null || price <= 0 || currency == null || currency.isEmpty) continue;
    final loc = it['location'];
    String? place;
    if (loc is Map) {
      final parts = [loc['osm_name'], loc['osm_address_city']]
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) place = parts.join(', ');
    }
    out.add(PriceObservation(
      price: price,
      currency: currency,
      date: DateTime.tryParse(it['date']?.toString() ?? ''),
      place: place,
      perKilo: it['price_per']?.toString().toUpperCase() == 'KILOGRAM',
      discounted: it['price_is_discounted'] == true,
    ));
  }
  return out;
}

/// "1,29 €" ; devises autres que l'euro affichées avec leur code.
String formatPrice(double price, String currency) {
  final amount = price.toStringAsFixed(2).replaceAll('.', ',');
  return currency.toUpperCase() == 'EUR' ? '$amount €' : '$amount $currency';
}
