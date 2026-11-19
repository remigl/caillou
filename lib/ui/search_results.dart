import 'package:flutter/material.dart';

import '../data/ciqual/food_database.dart';
import '../data/ciqual/food_index.dart';
import '../services.dart';
import 'food_screen.dart';
import 'widgets/common.dart';

/// Résultats de recherche d'aliments génériques (Ciqual, hors ligne).
class SearchResults extends StatelessWidget {
  const SearchResults({super.key, required this.query, required this.onScan});

  final String query;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return FutureBuilder<FoodIndex>(
      future: services.foods.load(),
      initialData: services.foods.loaded,
      builder: (context, snap) {
        if (snap.hasError) {
          return MessageView(
            icon: Icons.cloud_off,
            title: 'Base d\'aliments indisponible',
            message: snap.error is FoodDatabaseMissing
                ? 'Cette version de l\'app a été construite sans la table Ciqual.'
                : '${snap.error}',
          );
        }
        final index = snap.data;
        if (index == null) return const Center(child: CircularProgressIndicator());

        final results = index.search(query);
        if (results.isEmpty) {
          return MessageView(
            icon: Icons.search_off,
            title: 'Aucun aliment trouvé pour « $query »',
            message: 'Essayez un mot simple (« tomate », « riz »). Pour un produit emballé, scannez son code-barres.',
            actionLabel: 'Scanner un produit',
            onAction: onScan,
          );
        }
        return ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: results.length + 1,
          separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Text('Valeurs pour 100 g · P protéines · G glucides · L lipides · F fibres',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )),
              );
            }
            final food = results[i - 1];
            return FoodTile(
              food: food,
              onTap: () {
                FocusScope.of(context).unfocus();
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FoodScreen(food: food)));
              },
            );
          },
        );
      },
    );
  }
}
