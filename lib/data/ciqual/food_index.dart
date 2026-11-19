import '../../core/text.dart';
import '../food_aliases.dart';
import 'ciqual_food.dart';

enum PreferredState { raw, cooked, any }

class ScoredFood {
  const ScoredFood(this.food, this.score);
  final CiqualFood food;
  final double score;
}

/// Recherche locale (hors ligne, instantanée) dans la table Ciqual.
class FoodIndex {
  FoodIndex(this.dataset) : _byCode = {for (final f in dataset.foods) f.code: f};

  final CiqualDataset dataset;
  final Map<int, CiqualFood> _byCode;

  List<CiqualFood> get foods => dataset.foods;

  CiqualFood? byCode(int code) => _byCode[code];

  List<CiqualFood> search(String query, {int limit = 40}) =>
      searchScored(query, limit: limit).map((s) => s.food).toList(growable: false);

  List<ScoredFood> searchScored(String query, {int limit = 40}) {
    final expansion = FoodAliases.expansionFor(query);
    // La requête réécrite par un alias ("pâtes" -> "pates seches") est un signal plus précis : +10.
    final queries = <(List<String>, double)>[
      (tokenize(query), 0.0),
      if (expansion != null) (tokenize(expansion), 10.0),
    ].where((q) => q.$1.isNotEmpty).toList();
    if (queries.isEmpty) return const [];
    final results = <ScoredFood>[];

    for (final f in dataset.foods) {
      double? best;
      for (final (q, boost) in queries) {
        final qKey = q.join(' ');
        var score = _scoreTokens(q, qKey, f.tokens, f.firstSegmentKey);
        if (score != null) score += f.rankBonus;
        if (score == null && f.tokensEn.isNotEmpty) {
          // Repli sur le nom anglais Ciqual ("broccoli", "apple"...), moins prioritaire.
          final en = _scoreTokens(q, qKey, f.tokensEn, phraseKey((f.nameEn ?? '').split(',').first));
          if (en != null) score = en - 25 + f.rankBonus;
        }
        if (score != null) score += boost;
        if (score != null && (best == null || score > best)) best = score;
      }
      if (best != null) results.add(ScoredFood(f, best));
    }

    results.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.food.name.length.compareTo(b.food.name.length);
    });
    return results.length > limit ? results.sublist(0, limit) : results;
  }

  /// Null si au moins un mot de la requête ne correspond à aucun mot du nom.
  static double? _scoreTokens(List<String> q, String qKey, List<String> name, String firstSegment) {
    if (name.isEmpty) return null;
    var score = 0.0;
    for (final qt in q) {
      final idx = name.indexWhere((t) => t.startsWith(qt));
      if (idx < 0) return null;
      if (name[idx] == qt) score += 6; // mot exact
      score += 4 - (idx > 4 ? 4 : idx); // plus le mot est tôt dans le nom, mieux c'est
    }
    if (firstSegment == qKey) {
      score += 100; // "Brocoli, cru" pour "brocoli"
    } else if (firstSegment.startsWith(qKey)) {
      score += 60; // "Oeuf dur" pour "oeuf"
    }
    if (name.first == q.first) score += 20;
    score -= name.length * 1.5; // les noms simples d'abord
    return score;
  }

  /// Meilleure correspondance pour un aliment reconnu sur une photo.
  CiqualFood? bestMatch(String query, {PreferredState prefer = PreferredState.any}) {
    final candidates = searchScored(query, limit: 25);
    if (candidates.isEmpty) return null;
    ScoredFood? best;
    double bestScore = double.negativeInfinity;
    for (final c in candidates) {
      final s = c.score + _stateBonus(c.food, prefer);
      if (s > bestScore) {
        bestScore = s;
        best = c;
      }
    }
    return best?.food;
  }

  static double _stateBonus(CiqualFood f, PreferredState prefer) {
    switch (prefer) {
      case PreferredState.raw:
        if (f.states.contains(FoodState.raw)) return 15;
        return f.states.isEmpty ? 5 : -5;
      case PreferredState.cooked:
        if (f.states.contains(FoodState.cooked)) return 15;
        return f.states.isEmpty ? 5 : -5;
      case PreferredState.any:
        return 0;
    }
  }

  /// Autres préparations du même aliment : "Brocoli, cru" -> cuit, surgelé...
  List<CiqualFood> variantsOf(CiqualFood food, {int limit = 12}) {
    return dataset.foods
        .where((f) => f.code != food.code && f.firstSegmentKey == food.firstSegmentKey)
        .take(limit)
        .toList(growable: false);
  }
}
