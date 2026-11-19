import '../config.dart';
import '../core/text.dart';
import '../data/ciqual/ciqual_food.dart';
import '../data/ciqual/food_index.dart';
import '../data/food_aliases.dart';
import 'food_recognizer.dart';

/// Résultat affiché pour un aliment reconnu : ce qui a été vu + la fiche Ciqual retenue.
class RecognizedItem {
  RecognizedItem({
    required this.detection,
    required this.displayName,
    required this.emoji,
    this.match,
    this.confirmed = false,
  });

  final DetectedFood detection;
  String displayName;
  String emoji;

  /// Fiche nutritionnelle retenue (modifiable par l'utilisateur).
  CiqualFood? match;

  /// L'utilisateur a validé ou corrigé cet aliment.
  bool confirmed;

  bool get isConfident => detection.confidence >= AppConfig.recognitionConfidenceThreshold;
  bool get needsReview => !confirmed && !isConfident;
}

/// Couche de normalisation : nom renvoyé par le modèle (souvent anglais) -> aliment canonique -> fiche Ciqual.
class FoodMatcher {
  FoodMatcher(this.index);

  /// Null si la base Ciqual n'est pas disponible : on affiche alors seulement les noms.
  final FoodIndex? index;

  List<RecognizedItem> resolveAll(List<DetectedFood> detections) {
    final byKey = <String, RecognizedItem>{};
    for (final d in detections) {
      final item = resolve(d);
      final key = item.match != null ? 'c${item.match!.code}' : 'n${phraseKey(item.displayName)}';
      final existing = byKey[key];
      // Doublons (ex. "tomato" et "cherry tomato" -> même fiche) : on garde la meilleure confiance.
      if (existing == null || existing.detection.confidence < d.confidence) byKey[key] = item;
    }
    final items = byKey.values.toList()
      ..sort((a, b) => b.detection.confidence.compareTo(a.detection.confidence));
    return items;
  }

  RecognizedItem resolve(DetectedFood d) {
    final canonical = FoodAliases.lookup(d.nameFr) ?? FoodAliases.lookup(d.nameEn);
    final displayName = capitalize(canonical?.name ?? (d.nameFr.isNotEmpty ? d.nameFr : d.nameEn));
    final prefer = switch (d.state) {
      'raw' => PreferredState.raw,
      'cooked' => PreferredState.cooked,
      _ => canonical?.prefer ?? PreferredState.raw,
    };

    CiqualFood? match;
    final idx = index;
    if (idx != null) {
      final queries = <String>[
        if (canonical != null) canonical.ciqualQuery,
        if (d.nameFr.isNotEmpty) d.nameFr,
        if (d.nameEn.isNotEmpty) d.nameEn,
      ];
      for (final q in queries) {
        match = idx.bestMatch(q, prefer: prefer);
        if (match != null) break;
      }
    }

    return RecognizedItem(
      detection: d,
      displayName: displayName,
      emoji: canonical?.emoji ?? '🍽️',
      match: match,
    );
  }
}
