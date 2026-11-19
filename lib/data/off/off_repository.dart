import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../config.dart';
import 'off_api.dart';
import 'off_product.dart';

class ProductResult {
  const ProductResult(this.product, {required this.fetchedAt, this.fromCache = false, this.stale = false});

  final OffProduct product;
  final DateTime fetchedAt;
  final bool fromCache;

  /// Copie locale ancienne servie faute de réseau.
  final bool stale;
}

/// Cache local des réponses produit (LRU simple, 100 produits).
class ProductCache {
  ProductCache(this._prefs);

  final SharedPreferences _prefs;
  static const _prefix = 'off.product.';
  static const _indexKey = 'off.index';
  static const maxEntries = 100;

  ({Map<String, dynamic> json, DateTime fetchedAt})? get(String barcode) {
    final raw = _prefs.getString('$_prefix$barcode');
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return (
        json: Map<String, dynamic>.from(m['p'] as Map),
        fetchedAt: DateTime.fromMillisecondsSinceEpoch((m['t'] as num).toInt()),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String barcode, Map<String, dynamic> json) async {
    await _prefs.setString(
      '$_prefix$barcode',
      jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'p': json}),
    );
    final index = List<String>.from(_prefs.getStringList(_indexKey) ?? const <String>[])
      ..remove(barcode)
      ..insert(0, barcode);
    while (index.length > maxEntries) {
      await _prefs.remove('$_prefix${index.removeLast()}');
    }
    await _prefs.setStringList(_indexKey, index);
  }

  Future<void> clear() async {
    for (final code in _prefs.getStringList(_indexKey) ?? const <String>[]) {
      await _prefs.remove('$_prefix$code');
    }
    await _prefs.remove(_indexKey);
  }
}

/// Cache d'abord (moins d'appels, fonctionne hors ligne), réseau ensuite.
class OffRepository {
  OffRepository({required this.api, required this.cache});

  final OffApi api;
  final ProductCache cache;

  Future<ProductResult> getProduct(String rawBarcode, {bool forceRefresh = false}) async {
    final barcode = OffApi.cleanBarcode(rawBarcode);
    if (barcode == null) throw OffInvalidBarcode(rawBarcode);

    final cached = cache.get(barcode);
    if (!forceRefresh && cached != null &&
        DateTime.now().difference(cached.fetchedAt) < AppConfig.productCacheFreshness) {
      return ProductResult(OffProduct.fromJson(cached.json, barcode: barcode),
          fetchedAt: cached.fetchedAt, fromCache: true);
    }

    try {
      final json = await api.fetchProductJson(barcode);
      await cache.put(barcode, json);
      return ProductResult(OffProduct.fromJson(json, barcode: barcode), fetchedAt: DateTime.now());
    } on OffException catch (e) {
      // Réseau coupé ou limite atteinte : on sert la copie locale si elle existe.
      final transient = e is OffNetworkError || e is OffRateLimited || e is OffServerError;
      if (transient && cached != null) {
        return ProductResult(OffProduct.fromJson(cached.json, barcode: barcode),
            fetchedAt: cached.fetchedAt, fromCache: true, stale: true);
      }
      rethrow;
    }
  }
}
