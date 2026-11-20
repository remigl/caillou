import 'package:flutter/material.dart';

import '../data/ciqual/ciqual_food.dart';
import '../data/history_store.dart';
import '../data/meal.dart';
import '../services.dart';
import 'meal_screen.dart';
import 'widgets/common.dart';
import 'widgets/detailed_composition.dart';
import 'widgets/nutrition_table.dart';

/// Fiche d'un aliment générique (table Ciqual).
class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key, required this.food});

  final CiqualFood food;

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final f = widget.food;
      AppScope.of(context).history.add(HistoryEntry(
            kind: HistoryKind.food,
            id: '${f.code}',
            title: f.name,
            subtitle: f.group,
            kcal: f.nutrition.kcalLabel(),
            at: DateTime.now(),
          ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final theme = Theme.of(context);
    final services = AppScope.of(context);
    final index = services.foods.loaded;
    final variants = index?.variantsOf(food) ?? const <CiqualFood>[];
    final defs = index?.dataset.detailDefs ?? const <DetailDef>[];
    final showsPreparation = food.states.contains(FoodState.raw) || food.states.contains(FoodState.cooked);

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(food.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
          if (food.group != null) ...[
            const SizedBox(height: 4),
            Text(food.group!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 8),
          StateChips(food.states),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () async {
                await services.meal.add(MealItem.fromFood(food, defs));
                if (context.mounted) showAddedToMeal(context, food.name.split(',').first);
              },
              icon: const Icon(Icons.restaurant_outlined),
              label: const Text('Ajouter au repas'),
            ),
          ),
          const SizedBox(height: 16),
          NutritionTable(nutrition: food.nutrition),
          CarbReference(nutrition: food.nutrition),
          if (showsPreparation) ...[
            const SizedBox(height: 12),
            Text(
              'Les valeurs changent beaucoup entre cru et cuit (eau absorbée ou perdue) : choisissez la bonne préparation.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          if (food.details.isNotEmpty && defs.isNotEmpty) ...[
            const SectionTitle('Composition détaillée'),
            DetailedComposition(food: food, defs: defs),
            const NrvLegend(),
          ],
          AminoSection(ciqualCode: food.code),
          if (variants.isNotEmpty) ...[
            const SectionTitle('Autres préparations'),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final v in variants)
                    FoodTile(
                      food: v,
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(builder: (_) => FoodScreen(food: v)),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Source : Anses, table de composition nutritionnelle Ciqual 2025 (Licence Ouverte 2.0). '
            'Valeurs moyennes pour 100 g de partie comestible. Informations indicatives, pas un avis médical.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
