import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'food_recognizer.dart';
import 'recognition_settings.dart';

const String kRecognitionPrompt = '''
Tu es un module de reconnaissance d'aliments pour une application de nutrition.
Liste chaque aliment DISTINCT visible sur la photo (fruits, légumes, féculents, viandes, produits laitiers, plats simples).
Règles :
- Un aliment n'apparaît qu'une fois, même s'il y en a plusieurs (trois pommes -> une seule entrée "pomme").
- Ne compte pas, n'estime ni poids ni quantité ni calories.
- Nom générique et simple, au singulier ("carotte", pas "carottes râpées bio").
- state : "raw" (cru), "cooked" (cuit) ou "unknown".
- confidence : ta probabilité (0 à 1) que l'identification soit correcte. Sois honnête : en cas de doute, mets une valeur basse.
- Ignore emballages, couverts, assiettes, personnes et décor.
Réponds UNIQUEMENT avec ce JSON, sans texte autour :
{"foods":[{"name_en":"apple","name_fr":"pomme","state":"raw","confidence":0.97}]}
S'il n'y a aucun aliment : {"foods":[]}''';

/// Reconnaissance via un modèle de vision exposé par une API compatible
/// « Chat Completions » (Mistral, Ollama, proxy Caillou, etc.).
class RemoteVisionRecognizer implements FoodRecognizer {
  RemoteVisionRecognizer(this._client, this._settings);

  final http.Client _client;
  final RecognitionSettings _settings;
  static const timeout = Duration(seconds: 60);

  @override
  Future<List<DetectedFood>> recognize(Uint8List imageBytes) async {
    if (!_settings.isConfigured) {
      throw const RecognitionException('La reconnaissance photo n\'est pas configurée.', canRetry: false);
    }
    final dataUrl = 'data:${_mimeType(imageBytes)};base64,${base64Encode(imageBytes)}';

    var res = await _post(_body(dataUrl, jsonMode: true));
    // Certains serveurs refusent response_format avec des images : un essai sans.
    if (res.statusCode == 400 || res.statusCode == 422) {
      res = await _post(_body(dataUrl, jsonMode: false));
    }

    switch (res.statusCode) {
      case 200:
        break;
      case 401:
      case 403:
        throw const RecognitionException('Clé ou jeton refusé par le service de reconnaissance. Vérifiez les réglages.',
            canRetry: false);
      case 404:
        throw const RecognitionException('Adresse ou modèle introuvable. Vérifiez les réglages.', canRetry: false);
      case 413:
        throw const RecognitionException('Photo trop lourde pour le service.');
      case 429:
        throw const RecognitionException('Trop de demandes : le service limite l\'usage. Réessayez dans un instant.');
      default:
        throw RecognitionException('Le service de reconnaissance a répondu ${res.statusCode}. ${_errorDetail(res)}'.trim());
    }

    final Object? json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw const RecognitionException('Réponse du service illisible.');
    }
    return parseDetections(_extractContent(json));
  }

  Map<String, dynamic> _body(String dataUrl, {required bool jsonMode}) => {
        'model': _settings.model,
        'temperature': 0,
        'max_tokens': 800,
        if (jsonMode) 'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': kRecognitionPrompt},
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Quels aliments vois-tu sur cette photo ?'},
              {
                'type': 'image_url',
                'image_url': {'url': dataUrl},
              },
            ],
          },
        ],
      };

  Future<http.Response> _post(Map<String, dynamic> body) async {
    try {
      return await _client
          .post(
            _settings.endpoint,
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': AppConfig.userAgent,
              if (_settings.apiKey.isNotEmpty) 'Authorization': 'Bearer ${_settings.apiKey}',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const RecognitionException('Le service met trop de temps à répondre.');
    } on SocketException {
      throw const RecognitionException('Pas de connexion au service de reconnaissance.');
    } on http.ClientException {
      throw const RecognitionException('Pas de connexion au service de reconnaissance.');
    } on HandshakeException {
      throw const RecognitionException('Connexion sécurisée impossible avec le service (certificat).');
    }
  }

  static String _extractContent(Object? json) {
    if (json is Map) {
      final choices = json['choices'];
      if (choices is List && choices.isNotEmpty && choices.first is Map) {
        final message = (choices.first as Map)['message'];
        if (message is Map) {
          final content = message['content'];
          if (content is String) return content;
          if (content is List) {
            // Format « parts » : [{"type":"text","text":"..."}]
            return content
                .whereType<Map>()
                .map((p) => p['text'])
                .whereType<String>()
                .join();
          }
        }
      }
    }
    throw const RecognitionException('Réponse du service inattendue.');
  }

  static String _errorDetail(http.Response res) {
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (j is Map) {
        final e = j['error'];
        if (e is Map && e['message'] is String) return e['message'] as String;
        if (e is String) return e;
        if (j['message'] is String) return j['message'] as String;
      }
    } catch (_) {}
    return '';
  }

  static String _mimeType(Uint8List b) {
    if (b.length > 4 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
    if (b.length > 12 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) return 'image/webp';
    return 'image/jpeg';
  }
}
