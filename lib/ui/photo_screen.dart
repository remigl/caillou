import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/ciqual/food_index.dart';
import '../recognition/food_matcher.dart';
import '../recognition/food_recognizer.dart';
import '../recognition/remote_vision_recognizer.dart';
import '../services.dart';
import 'food_picker_sheet.dart';
import 'food_screen.dart';
import 'settings_screen.dart';
import 'widgets/common.dart';

/// Photo de plusieurs aliments -> liste des aliments reconnus + valeurs pour 100 g.
class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  Future<List<RecognizedItem>>? _future;
  List<RecognizedItem>? _items;
  FoodIndex? _index;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _analyze();
  }

  Future<List<RecognizedItem>> _analyze() async {
    final services = AppScope.of(context);
    final recognizer = RemoteVisionRecognizer(services.httpClient, services.recognitionSettings.load());
    final detections = await recognizer.recognize(widget.imageBytes);
    try {
      _index = await services.foods.load();
    } catch (_) {
      _index = null; // On affiche quand même les aliments reconnus.
    }
    final items = FoodMatcher(_index).resolveAll(detections);
    _items = items;
    return items;
  }

  void _retry() => setState(() {
        _items = null;
        _future = _analyze();
      });

  Future<void> _correct(RecognizedItem item) async {
    final index = _index;
    if (index == null) return;
    final food = await pickFood(context, index: index, initialQuery: item.displayName);
    if (food == null || !mounted) return;
    setState(() {
      item.match = food;
      item.displayName = food.name.split(',').first;
      item.confirmed = true;
    });
  }

  void _confirm(RecognizedItem item) => setState(() => item.confirmed = true);

  void _remove(RecognizedItem item) => setState(() => _items?.remove(item));

  Future<void> _addManually() async {
    final index = _index;
    if (index == null) return;
    final food = await pickFood(context, index: index);
    if (food == null || !mounted) return;
    setState(() {
      _items?.add(RecognizedItem(
        detection: DetectedFood(nameEn: '', nameFr: food.name, confidence: 1),
        displayName: food.name.split(',').first,
        emoji: '➕',
        match: food,
        confirmed: true,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aliments sur la photo')),
      body: FutureBuilder<List<RecognizedItem>>(
        future: _future,
        builder: (context, snap) {
          final header = _PhotoHeader(bytes: widget.imageBytes);
          if (snap.connectionState != ConnectionState.done) {
            return ListView(padding: const EdgeInsets.all(16), children: [
              header,
              const SizedBox(height: 32),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              const Center(child: Text('Reconnaissance des aliments…')),
            ]);
          }
          if (snap.hasError) {
            final e = snap.error;
            final canRetry = e is! RecognitionException || e.canRetry;
            return ListView(padding: const EdgeInsets.all(16), children: [
              header,
              MessageView(
                icon: Icons.error_outline,
                title: 'Reconnaissance impossible',
                message: e is RecognitionException ? e.message : '$e',
                actionLabel: canRetry ? 'Réessayer' : 'Ouvrir les réglages',
                onAction: canRetry
                    ? _retry
                    : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
              ),
            ]);
          }
          return _results(context, header, _items ?? snap.data ?? const []);
        },
      ),
    );
  }

  Widget _results(BuildContext context, Widget header, List<RecognizedItem> items) {
    final theme = Theme.of(context);
    final sure = items.where((i) => !i.needsReview).toList();
    final review = items.where((i) => i.needsReview).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        header,
        if (_index == null)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Base d\'aliments indisponible : seuls les noms sont affichés.'),
          ),
        if (items.isEmpty)
          MessageView(
            icon: Icons.no_food_outlined,
            title: 'Aucun aliment reconnu sur cette photo',
            message: 'Essayez avec plus de lumière, ou ajoutez l\'aliment vous-même.',
            actionLabel: _index != null ? 'Ajouter un aliment' : null,
            onAction: _index != null ? _addManually : null,
          ),
        if (sure.isNotEmpty) ...[
          const SectionTitle('Aliments détectés'),
          for (final item in sure) _ItemCard(item: item, onCorrect: _correct, onRemove: _remove, onOpen: _open),
        ],
        if (review.isNotEmpty) ...[
          const SectionTitle('À vérifier'),
          for (final item in review)
            _ItemCard(item: item, onCorrect: _correct, onRemove: _remove, onOpen: _open, onConfirm: _confirm),
        ],
        if (items.isNotEmpty && _index != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addManually,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un aliment oublié'),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Valeurs pour 100 g. Les quantités présentes sur la photo ne sont pas estimées. '
          'La confiance est indiquée par le modèle de vision : elle reste approximative.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  void _open(RecognizedItem item) {
    final food = item.match;
    if (food == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FoodScreen(food: food)));
  }
}

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.memory(bytes, height: 180, width: double.infinity, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.onCorrect,
    required this.onRemove,
    required this.onOpen,
    this.onConfirm,
  });

  final RecognizedItem item;
  final ValueChanged<RecognizedItem> onCorrect;
  final ValueChanged<RecognizedItem> onRemove;
  final ValueChanged<RecognizedItem> onOpen;
  final ValueChanged<RecognizedItem>? onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final match = item.match;
    final pct = (item.detection.confidence * 100).round();
    final uncertain = item.needsReview;
    final kcal = match?.nutrition.kcalLabel();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: match == null ? () => onCorrect(item) : () => onOpen(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  if (!item.confirmed || item.detection.confidence < 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: uncertain ? scheme.errorContainer : scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$pct %',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: uncertain ? scheme.onErrorContainer : scheme.onPrimaryContainer,
                          )),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'Options',
                    onSelected: (v) {
                      if (v == 'fix') {
                        onCorrect(item);
                      } else {
                        onRemove(item);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'fix', child: Text('Corriger l\'aliment')),
                      PopupMenuItem(value: 'remove', child: Text('Retirer')),
                    ],
                  ),
                ],
              ),
              if (uncertain) ...[
                const SizedBox(height: 4),
                Text('Je ne suis pas certain de cet aliment.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error)),
              ],
              const SizedBox(height: 6),
              if (match != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(match.name,
                          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Text(kcal == null ? 'kcal n.d.' : '$kcal / 100 g',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                  ],
                ),
                const SizedBox(height: 2),
                Text(match.nutrition.shortMacros(), style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                StateChips(match.states),
              ] else
                Text('Aucune fiche nutritionnelle trouvée. Touchez pour choisir l\'aliment.',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              if (uncertain)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(spacing: 8, children: [
                    if (onConfirm != null)
                      FilledButton.tonal(onPressed: () => onConfirm!(item), child: const Text('C\'est bien ça')),
                    OutlinedButton(onPressed: () => onCorrect(item), child: const Text('Corriger')),
                  ]),
                )
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => onCorrect(item),
                    child: Text(match == null ? 'Choisir' : 'Changer de préparation'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
