import 'package:shared_preferences/shared_preferences.dart';

/// Configuration du moteur de reconnaissance : n'importe quelle API compatible
/// « OpenAI Chat Completions » avec images (Mistral, Ollama local, proxy Caillou...).
class RecognitionSettings {
  const RecognitionSettings({this.baseUrl = '', this.model = '', this.apiKey = ''});

  /// Ex. https://api.mistral.ai/v1 — l'app appelle `{baseUrl}/chat/completions`.
  final String baseUrl;
  final String model;

  /// Clé personnelle (stockée uniquement sur le téléphone) ou jeton du proxy. Peut être vide.
  final String apiKey;

  bool get isConfigured => Uri.tryParse(baseUrl.trim())?.hasScheme == true && model.trim().isNotEmpty;

  Uri get endpoint {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return Uri.parse('$base/chat/completions');
  }

  RecognitionSettings copyWith({String? baseUrl, String? model, String? apiKey}) => RecognitionSettings(
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
      );
}

class RecognitionPreset {
  const RecognitionPreset(this.label, this.baseUrl, this.model, this.help);
  final String label;
  final String baseUrl;
  final String model;
  final String help;

  static const presets = [
    RecognitionPreset(
      'Mistral',
      'https://api.mistral.ai/v1',
      'mistral-small-latest',
      'Clé personnelle sur console.mistral.ai (modèles à poids ouverts, hébergés en Europe).',
    ),
    RecognitionPreset(
      'Proxy Caillou',
      'https://VOTRE-PROXY.workers.dev/v1',
      'auto',
      'Votre proxy (dossier proxy/ du dépôt) : la clé reste sur le serveur. Jeton facultatif.',
    ),
    RecognitionPreset(
      'Local (Ollama)',
      'https://VOTRE-PC/v1',
      'qwen2.5vl:7b',
      'Modèle libre sur votre PC via Ollama, exposé en HTTPS (ex. tailscale serve). Aucune clé.',
    ),
  ];
}

class RecognitionSettingsStore {
  RecognitionSettingsStore(this._prefs);
  final SharedPreferences _prefs;

  static const _kBase = 'vision.baseUrl';
  static const _kModel = 'vision.model';
  static const _kKey = 'vision.apiKey';

  RecognitionSettings load() => RecognitionSettings(
        baseUrl: _prefs.getString(_kBase) ?? '',
        model: _prefs.getString(_kModel) ?? '',
        apiKey: _prefs.getString(_kKey) ?? '',
      );

  Future<void> save(RecognitionSettings s) async {
    await _prefs.setString(_kBase, s.baseUrl.trim());
    await _prefs.setString(_kModel, s.model.trim());
    await _prefs.setString(_kKey, s.apiKey.trim());
  }
}
