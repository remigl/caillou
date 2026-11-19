import 'package:flutter/material.dart';

import '../data/history_store.dart';
import '../data/off/off_api.dart';
import '../data/off/off_product.dart';
import '../data/off/off_repository.dart';
import '../services.dart';
import 'scanner_screen.dart';
import 'widgets/common.dart';
import 'widgets/nutrition_table.dart';

/// Fiche d'un produit emballé (Open Food Facts).
class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.barcode});

  final String barcode;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late Future<ProductResult> _future;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _future = _load();
    }
  }

  Future<ProductResult> _load({bool force = false}) async {
    final services = AppScope.of(context);
    final result = await services.products.getProduct(widget.barcode, forceRefresh: force);
    final p = result.product;
    await services.history.add(HistoryEntry(
      kind: HistoryKind.product,
      id: p.barcode,
      title: p.displayName,
      subtitle: p.brand,
      kcal: p.nutrition.kcalLabel(),
      at: DateTime.now(),
    ));
    return result;
  }

  void _retry() => setState(() => _future = _load(force: true));

  void _scanAnother() => Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ScannerScreen()),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<ProductResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = snap.error;
          if (error != null) return _errorView(error);
          return RefreshIndicator(
            onRefresh: () async {
              final next = _load(force: true);
              setState(() => _future = next);
              try {
                await next;
              } catch (_) {
                // L'erreur est affichée par le FutureBuilder.
              }
            },
            child: _ProductView(result: snap.data!),
          );
        },
      ),
    );
  }

  Widget _errorView(Object error) {
    if (error is OffProductNotFound) {
      return MessageView(
        icon: Icons.search_off,
        title: 'Produit introuvable',
        message: '${error.message}\nCode-barres : ${error.barcode}\n\n'
            'Open Food Facts est une base collaborative : vous pouvez y ajouter ce produit (openfoodfacts.org).',
        actionLabel: 'Scanner un autre produit',
        onAction: _scanAnother,
        secondaryLabel: 'Retour',
        onSecondary: () => Navigator.of(context).pop(),
      );
    }
    final message = error is OffException ? error.message : 'Erreur inattendue : $error';
    final canRetry = error is! OffInvalidBarcode;
    return MessageView(
      icon: error is OffNetworkError ? Icons.wifi_off : Icons.error_outline,
      title: 'Impossible d\'afficher ce produit',
      message: message,
      actionLabel: canRetry ? 'Réessayer' : 'Scanner à nouveau',
      onAction: canRetry ? _retry : _scanAnother,
    );
  }
}

class _ProductView extends StatelessWidget {
  const _ProductView({required this.result});

  final ProductResult result;

  @override
  Widget build(BuildContext context) {
    final p = result.product;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        if (result.stale)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Hors ligne : données enregistrées le ${_date(result.fetchedAt)}.',
                style: theme.textTheme.bodySmall),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProductImage(url: p.imageUrl),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.displayName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  if (p.brand != null) ...[const SizedBox(height: 4), Text(p.brand!, style: muted)],
                  if (p.quantity != null) ...[const SizedBox(height: 2), Text(p.quantity!, style: muted)],
                  if (p.nutriScore != null || p.nova != null) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (p.nutriScore != null)
                        _ScoreChip(
                            label: 'Nutri-Score', value: p.nutriScore!.toUpperCase(), color: _nutriColor(p.nutriScore)),
                      if (p.nova != null) _ScoreChip(label: 'NOVA', value: '${p.nova}', color: _novaColor(p.nova)),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (p.nova != null) ...[
          const SizedBox(height: 8),
          Text('NOVA ${p.nova} : ${_novaLabel(p.nova!)}', style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 20),
        if (p.nutritionNotProvided || p.nutrition.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              p.nutritionNotProvided
                  ? 'Informations nutritionnelles non indiquées sur l\'emballage.'
                  : 'Informations nutritionnelles non disponibles pour ce produit.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          NutritionTable(nutrition: p.nutrition, basis: p.isLiquid ? 'Pour 100 ml' : 'Pour 100 g'),
        _InfoSection(title: 'Catégorie', text: p.category),
        _InfoSection(title: 'Ingrédients', text: p.ingredients),
        _InfoSection(title: 'Allergènes', text: p.allergens.isEmpty ? null : p.allergens.join(', '),
            emptyText: 'Aucun allergène renseigné (ce qui ne garantit pas leur absence).'),
        if (p.traces.isNotEmpty) _InfoSection(title: 'Traces éventuelles', text: p.traces.join(', ')),
        _InfoSection(title: 'Labels', text: p.labels.isEmpty ? null : p.labels.join(', '), emptyText: 'Aucun label renseigné.'),
        const SizedBox(height: 24),
        Text(
          'Code-barres ${p.barcode}. Données : Open Food Facts et ses contributeurs (licence ODbL), '
          'photos sous licence CC BY-SA. Données collaboratives : vérifiez l\'emballage en cas de doute '
          '(allergies notamment).',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static Color? _nutriColor(String? g) => switch (g) {
        'a' => const Color(0xFF1E8F4E),
        'b' => const Color(0xFF7AC143),
        'c' => const Color(0xFFF2C200),
        'd' => const Color(0xFFEF7D00),
        'e' => const Color(0xFFE63312),
        _ => null,
      };

  static Color? _novaColor(int? n) => switch (n) {
        1 => const Color(0xFF1E8F4E),
        2 => const Color(0xFFF2C200),
        3 => const Color(0xFFEF7D00),
        4 => const Color(0xFFE63312),
        _ => null,
      };

  static String _novaLabel(int n) => switch (n) {
        1 => 'aliment pas ou peu transformé',
        2 => 'ingrédient culinaire transformé',
        3 => 'aliment transformé',
        _ => 'aliment ultra-transformé',
      };
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: 96,
      height: 96,
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.inventory_2_outlined, color: scheme.onSurfaceVariant),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: url == null
          ? placeholder
          : Image.network(
              url!,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
              loadingBuilder: (context, child, progress) => progress == null ? child : placeholder,
            ),
    );
  }
}

/// Score affiché sous forme de texte (lettre / chiffre). Pas de reproduction des logos officiels.
class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.label, this.value, this.color});

  final String label;
  final String? value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(width: 6),
        Container(
          constraints: const BoxConstraints(minWidth: 26),
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color ?? scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            value ?? '?',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: color == null ? scheme.onSurfaceVariant : Colors.white,
            ),
          ),
        ),
      ]),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, this.text, this.emptyText = 'Non renseigné.'});

  final String title;
  final String? text;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            text ?? emptyText,
            style: text == null
                ? theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)
                : theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
