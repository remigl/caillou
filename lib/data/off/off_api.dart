import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../config.dart';
import 'off_product.dart';

/// Erreurs Open Food Facts, chacune avec un message affichable.
sealed class OffException implements Exception {
  const OffException();
  String get message;
  @override
  String toString() => message;
}

class OffInvalidBarcode extends OffException {
  const OffInvalidBarcode(this.barcode);
  final String barcode;
  @override
  String get message => 'Code-barres invalide : « $barcode ».';
}

class OffProductNotFound extends OffException {
  const OffProductNotFound(this.barcode);
  final String barcode;
  @override
  String get message => 'Ce produit n\'est pas (encore) dans Open Food Facts.';
}

class OffNetworkError extends OffException {
  const OffNetworkError();
  @override
  String get message => 'Pas de connexion. Vérifiez le réseau puis réessayez.';
}

class OffRateLimited extends OffException {
  const OffRateLimited();
  @override
  String get message => 'Open Food Facts limite le nombre de requêtes. Réessayez dans une minute.';
}

class OffServerError extends OffException {
  const OffServerError(this.status);
  final int status;
  @override
  String get message => 'Open Food Facts ne répond pas correctement (erreur $status). Réessayez plus tard.';
}

/// Client minimal de l'API Open Food Facts.
///
/// - Lecture produit : `GET /api/v3.4/product/{code}` (API v3, recommandée).
///   La version 3.4 est figée volontairement : la 3.5 introduit une nouvelle
///   structure des nutriments encore en développement ; 3.4 garde `nutriments.*_100g`.
/// - User-Agent obligatoire : `NomApp/Version (contact)`.
/// - Limite : 15 lectures produit / minute / IP -> l'app met en cache chaque produit.
class OffApi {
  OffApi(this._client, {this.baseUrl = 'https://world.openfoodfacts.org'});

  final http.Client _client;
  final String baseUrl;
  static const apiVersion = 'v3.4';
  static const timeout = Duration(seconds: 12);

  static final RegExp _barcodeRe = RegExp(r'^\d{6,14}$');

  static String? cleanBarcode(String raw) {
    final digits = raw.replaceAll(RegExp(r'[\s-]'), '');
    return _barcodeRe.hasMatch(digits) ? digits : null;
  }

  /// Retourne l'objet `product` brut (mis en cache tel quel).
  Future<Map<String, dynamic>> fetchProductJson(String rawBarcode) async {
    final barcode = cleanBarcode(rawBarcode);
    if (barcode == null) throw OffInvalidBarcode(rawBarcode);

    final uri = Uri.parse('$baseUrl/api/$apiVersion/product/$barcode').replace(queryParameters: {
      'fields': OffProduct.apiFields.join(','),
      'lc': 'fr',
    });

    final http.Response res;
    try {
      res = await _client.get(uri, headers: {
        'User-Agent': AppConfig.userAgent,
        'Accept': 'application/json',
      }).timeout(timeout);
    } on TimeoutException {
      throw const OffNetworkError();
    } on SocketException {
      throw const OffNetworkError();
    } on http.ClientException {
      throw const OffNetworkError();
    } on HandshakeException {
      throw const OffNetworkError();
    }

    if (res.statusCode == 404) throw OffProductNotFound(barcode);
    if (res.statusCode == 429) throw const OffRateLimited();
    if (res.statusCode != 200) throw OffServerError(res.statusCode);

    final Object? body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw OffServerError(res.statusCode);
    }
    if (body is! Map<String, dynamic>) throw OffServerError(res.statusCode);

    final status = body['status'];
    final product = body['product'];
    if (product is! Map || status == 'failure' || status == 0) {
      throw OffProductNotFound(barcode);
    }
    return Map<String, dynamic>.from(product);
  }
}
