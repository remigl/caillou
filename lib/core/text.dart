/// Normalisation de texte pour la recherche (accents, casse, pluriels simples).
library;

const Map<String, String> _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'æ': 'ae', //
  'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'í': 'i', 'ì': 'i', //
  'î': 'i', 'ï': 'i', 'ñ': 'n', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', //
  'õ': 'o', 'œ': 'oe', 'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y',
};

final RegExp _combining = RegExp('[̀-ͯ]');
final RegExp _nonAlnum = RegExp('[^a-z0-9]+');

/// "Pâtes alimentaires, cuites" -> "pates alimentaires cuites".
String normalizeText(String input) {
  final lower = input.toLowerCase().replaceAll(_combining, '');
  final b = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    b.write(_accents[ch] ?? ch);
  }
  return b.toString().replaceAll(_nonAlnum, ' ').trim();
}

/// Pluriel simple : "carottes" -> "carotte", "poireaux" -> "poireau". Les mots courts restent intacts ("noix", "pois", "riz").
String stemToken(String token) {
  if (token.length > 4 && (token.endsWith('s') || token.endsWith('x'))) {
    return token.substring(0, token.length - 1);
  }
  return token;
}

List<String> tokenize(String input) {
  final n = normalizeText(input);
  if (n.isEmpty) return const [];
  return n.split(' ').map(stemToken).toList(growable: false);
}

/// Clé de comparaison d'une expression : "Pommes de terre" -> "pomme de terre".
String phraseKey(String input) => tokenize(input).join(' ');

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
