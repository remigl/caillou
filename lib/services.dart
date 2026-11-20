import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'data/additives.dart';
import 'data/amino.dart';
import 'data/ciqual/food_database.dart';
import 'data/history_store.dart';
import 'data/meal.dart';
import 'data/recalls.dart';
import 'data/off/off_api.dart';
import 'data/off/off_repository.dart';
import 'data/off/open_prices.dart';
import 'recognition/recognition_settings.dart';

/// Toutes les dépendances de l'app, créées une fois au démarrage.
class Services {
  Services({
    required this.httpClient,
    required this.products,
    required this.productCache,
    required this.history,
    required this.foods,
    required this.recognitionSettings,
    required this.additives,
    required this.prices,
    required this.recalls,
    required this.meal,
    required this.amino,
  });

  final http.Client httpClient;
  final OffRepository products;
  final ProductCache productCache;
  final HistoryStore history;
  final FoodDatabase foods;
  final RecognitionSettingsStore recognitionSettings;
  final AdditiveDatabase additives;
  final OpenPricesApi prices;
  final RecallService recalls;
  final MealStore meal;
  final AminoDatabase amino;

  static Future<Services> create() async {
    final prefs = await SharedPreferences.getInstance();
    final client = http.Client();
    final cache = ProductCache(prefs);
    return Services(
      httpClient: client,
      products: OffRepository(api: OffApi(client), cache: cache),
      productCache: cache,
      history: HistoryStore(prefs),
      foods: FoodDatabase(),
      recognitionSettings: RecognitionSettingsStore(prefs),
      additives: AdditiveDatabase(),
      prices: OpenPricesApi(client),
      recalls: RecallService(client),
      meal: MealStore(prefs),
      amino: AminoDatabase(),
    );
  }
}

/// Rend [Services] accessible partout via `AppScope.of(context)`.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final Services services;

  static Services of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope manquant');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => !identical(services, oldWidget.services);
}
