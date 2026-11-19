import 'package:flutter/material.dart';

import '../config.dart';
import '../recognition/recognition_settings.dart';
import '../services.dart';
import 'widgets/common.dart';

/// Réglages de la reconnaissance photo + sources et licences.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  final _apiKey = TextEditingController();
  bool _loaded = false;
  bool _showKey = false;
  String? _help;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final s = AppScope.of(context).recognitionSettings.load();
    _baseUrl.text = s.baseUrl;
    _model.text = s.model;
    _apiKey.text = s.apiKey;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  void _applyPreset(RecognitionPreset p) {
    setState(() {
      _baseUrl.text = p.baseUrl;
      _model.text = p.model;
      _help = p.help;
    });
  }

  Future<void> _save() async {
    final settings = RecognitionSettings(baseUrl: _baseUrl.text, model: _model.text, apiKey: _apiKey.text);
    final messenger = ScaffoldMessenger.of(context);
    if (_baseUrl.text.trim().isNotEmpty && !settings.isConfigured) {
      messenger.showSnackBar(const SnackBar(content: Text('Adresse ou modèle invalide.')));
      return;
    }
    await AppScope.of(context).recognitionSettings.save(settings);
    messenger.showSnackBar(const SnackBar(content: Text('Réglages enregistrés.')));
  }

  Future<void> _clearData() async {
    final services = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await services.history.clear();
    await services.productCache.clear();
    messenger.showSnackBar(const SnackBar(content: Text('Historique et cache effacés.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const SectionTitle('Reconnaissance photo'),
          Text(
            'Caillou envoie la photo (réduite) au service choisi, uniquement quand vous la prenez. '
            'Toute API compatible « Chat Completions » avec images fonctionne.',
            style: muted,
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final p in RecognitionPreset.presets)
              ActionChip(label: Text(p.label), onPressed: () => _applyPreset(p)),
          ]),
          if (_help != null) ...[const SizedBox(height: 8), Text(_help!, style: muted)],
          const SizedBox(height: 16),
          TextField(
            controller: _baseUrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Adresse de l\'API', hintText: 'https://api.mistral.ai/v1'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _model,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Modèle', hintText: 'mistral-small-latest'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKey,
            autocorrect: false,
            obscureText: !_showKey,
            decoration: InputDecoration(
              labelText: 'Clé API ou jeton (facultatif)',
              suffixIcon: IconButton(
                icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showKey = !_showKey),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'La clé reste sur ce téléphone (stockage privé de l\'app, sauvegarde désactivée). '
            'Ne publiez jamais une app contenant une clé : pour partager Caillou, utilisez le proxy.',
            style: muted,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Enregistrer')),
          const SizedBox(height: 8),
          Text(
            'Seuil de confiance : ${(AppConfig.recognitionConfidenceThreshold * 100).round()} % '
            '(en dessous, l\'aliment est marqué « à vérifier »).',
            style: muted,
          ),
          const SectionTitle('Sources et licences'),
          Text(
            '• Produits emballés : Open Food Facts (openfoodfacts.org), base collaborative sous licence ODbL ; '
            'photos sous licence CC BY-SA. Données fournies sans garantie.\n'
            '• Aliments génériques : Anses, table de composition nutritionnelle Ciqual 2025, '
            'Licence Ouverte 2.0 (doi.org/10.57745/RDMHWY).\n'
            '• Caillou est indépendant : aucune donnée ni interface d\'une autre application de scan.',
            style: theme.textTheme.bodyMedium,
          ),
          const SectionTitle('Avertissement'),
          Text(
            'Informations nutritionnelles indicatives, pour 100 g. Ce n\'est pas un avis médical. '
            'En cas d\'allergie, fiez-vous toujours à l\'emballage.',
            style: theme.textTheme.bodyMedium,
          ),
          const SectionTitle('Données locales'),
          OutlinedButton(onPressed: _clearData, child: const Text('Effacer l\'historique et le cache')),
          const SizedBox(height: 16),
          Text('${AppConfig.appName} ${AppConfig.version}', style: muted, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
