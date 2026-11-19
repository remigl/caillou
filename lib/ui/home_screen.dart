import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/history_store.dart';
import '../services.dart';
import 'food_screen.dart';
import 'photo_screen.dart';
import 'product_screen.dart';
import 'scanner_screen.dart';
import 'search_results.dart';
import 'settings_screen.dart';
import 'widgets/common.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _go(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) setState(() {}); // rafraîchit l'historique
  }

  void _scan() {
    _focus.unfocus();
    _go(const ScannerScreen());
  }

  Future<void> _photo(ImageSource source) async {
    _focus.unfocus();
    final services = AppScope.of(context);
    if (!services.recognitionSettings.load().isConfigured) {
      final configure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reconnaissance photo'),
          content: const Text(
            'Pour reconnaître les aliments, Caillou utilise un modèle de vision. '
            'Choisissez un service (clé personnelle, votre proxy ou un modèle local) dans les réglages.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Plus tard')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Configurer')),
          ],
        ),
      );
      if (configure == true && mounted) _go(const SettingsScreen());
      return;
    }

    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 80);
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir ${source == ImageSource.camera ? 'l\'appareil photo' : 'la galerie'} (${e.code}).')),
      );
      return;
    }
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    _go(PhotoScreen(imageBytes: bytes));
  }

  Future<void> _openHistory(HistoryEntry e) async {
    final services = AppScope.of(context);
    switch (e.kind) {
      case HistoryKind.product:
        _go(ProductScreen(barcode: e.id));
      case HistoryKind.food:
        try {
          final index = await services.foods.load();
          final food = index.byCode(int.parse(e.id));
          if (food != null && mounted) _go(FoodScreen(food: food));
        } catch (_) {
          // Base absente : rien à ouvrir.
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searching = _query.text.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Text('Caillou', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Réglages',
                    icon: const Icon(Icons.tune),
                    onPressed: () => _go(const SettingsScreen()),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _query,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Rechercher un aliment',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searching
                      ? IconButton(
                          tooltip: 'Effacer',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_query.clear),
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: searching
                  ? SearchResults(query: _query.text.trim(), onScan: _scan)
                  : _HomeContent(
                      onScan: _scan,
                      onPhoto: () => _photo(ImageSource.camera),
                      onGallery: () => _photo(ImageSource.gallery),
                      onHistory: _openHistory,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.onScan, required this.onPhoto, required this.onGallery, required this.onHistory});

  final VoidCallback onScan;
  final VoidCallback onPhoto;
  final VoidCallback onGallery;
  final ValueChanged<HistoryEntry> onHistory;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final history = services.history.load();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.qr_code_scanner,
                label: 'Scanner\nun produit',
                onTap: onScan,
                primary: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.photo_camera_outlined,
                label: 'Prendre\nune photo',
                onTap: onPhoto,
                onLongPress: onGallery,
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onGallery,
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('Choisir une photo'),
          ),
        ),
        if (history.isNotEmpty) ...[
          const SectionTitle('Récemment consultés'),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final e in history.take(10))
                  ListTile(
                    leading: Icon(
                      e.kind == HistoryKind.product ? Icons.inventory_2_outlined : Icons.eco_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: e.subtitle == null ? null : Text(e.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: e.kcal == null ? null : Text(e.kcal!, style: theme.textTheme.labelLarge),
                    onTap: () => onHistory(e),
                  ),
              ],
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Text(
              'Scannez un produit, photographiez vos fruits et légumes\nou cherchez un aliment : valeurs pour 100 g.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.label, required this.onTap, this.onLongPress, this.primary = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = primary ? scheme.primaryContainer : scheme.secondaryContainer;
    final fg = primary ? scheme.onPrimaryContainer : scheme.onSecondaryContainer;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: fg),
              const SizedBox(height: 28),
              Text(label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w600, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}
