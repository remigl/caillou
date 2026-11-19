import 'dart:convert';
import 'dart:typed_data';

/// Un aliment repéré sur une photo. Aucune quantité, aucun poids : seulement « quoi ».
class DetectedFood {
  const DetectedFood({required this.nameEn, required this.nameFr, required this.confidence, this.state});

  final String nameEn;
  final String nameFr;

  /// 0..1
  final double confidence;

  /// "raw", "cooked" ou null si inconnu.
  final String? state;

  @override
  String toString() => 'DetectedFood($nameFr / $nameEn, $confidence, $state)';
}

/// Contrat commun : un moteur distant (modèle de vision) aujourd'hui, un modèle
/// embarqué demain, sans toucher à l'interface.
abstract interface class FoodRecognizer {
  Future<List<DetectedFood>> recognize(Uint8List imageBytes);
}

class RecognitionException implements Exception {
  const RecognitionException(this.message, {this.canRetry = true});
  final String message;
  final bool canRetry;
  @override
  String toString() => message;
}

/// Interprète la réponse texte du modèle : {"foods":[{"name_en","name_fr","confidence","state"}]}.
/// Tolère les blocs ```json, un tableau nu et une confiance exprimée en pourcentage.
List<DetectedFood> parseDetections(String content) {
  var text = content.trim();
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
  if (fence != null) text = fence.group(1)!.trim();

  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const RecognitionException('Réponse du modèle illisible.');
    }
    try {
      decoded = jsonDecode(text.substring(start, end + 1));
    } on FormatException {
      throw const RecognitionException('Réponse du modèle illisible.');
    }
  }

  final Object? list = decoded is Map ? (decoded['foods'] ?? decoded['items'] ?? decoded['aliments']) : decoded;
  if (list is! List) return const [];

  final out = <DetectedFood>[];
  for (final item in list) {
    if (item is! Map) continue;
    final fr = _s(item['name_fr']) ?? _s(item['nom']) ?? '';
    final en = _s(item['name_en']) ?? _s(item['name']) ?? '';
    if (fr.isEmpty && en.isEmpty) continue;
    out.add(DetectedFood(
      nameFr: fr,
      nameEn: en,
      confidence: _confidence(item['confidence']),
      state: _state(_s(item['state'])),
    ));
  }
  out.sort((a, b) => b.confidence.compareTo(a.confidence));
  return out;
}

String? _s(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// Confiance absente ou illisible = 0 : l'aliment sera « à vérifier », jamais validé d'office.
double _confidence(Object? v) {
  double? c = v is num ? v.toDouble() : double.tryParse(v?.toString().replaceAll('%', '').trim() ?? '');
  if (c == null || !c.isFinite) return 0;
  if (c > 1 && c <= 100) c = c / 100;
  return c.clamp(0.0, 1.0).toDouble();
}

String? _state(String? s) {
  switch (s?.toLowerCase()) {
    case 'raw':
    case 'cru':
      return 'raw';
    case 'cooked':
    case 'cuit':
      return 'cooked';
    default:
      return null;
  }
}
