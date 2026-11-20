import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/ciqual/food_index.dart';
import '../data/meal.dart';
import '../data/meal_suggestions.dart';
import '../services.dart';
import 'food_picker_sheet.dart';
import 'food_screen.dart';
import 'widgets/common.dart';
import 'widgets/nutrition_table.dart';

/// Composer un repas : éléments avec quantités, totaux et suggestions pour le compléter.
class MealScreen extends StatefulWidget {
  const MealScreen({super.key});

  @override
  State<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  FoodIndex? _index;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final foods = AppScope.of(context).foods;
    _index = foods.loaded;
    if (_index == null) {
      foods.load().then((i) {
        if (mounted) setState(() => _index = i);
      }).catchError((Object _) {});
    }
  }

  Future<void> _editGrams(MealItem item) async {
    final store = AppScope.of(context).meal;
    final controller = TextEditingController(text: item.grams.round().toString());
    final grams = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(suffixText: 'g', labelText: 'Quantité'),
          onSubmitted: (v) => Navigator.of(context).pop(double.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(double.tryParse(controller.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (grams != null && grams > 0 && grams <= 5000) await store.setGrams(item.key, grams);
  }

  Future<void> _addFood() async {
    final index = _index;
    if (index == null) return;
    final food = await pickFood(context, index: index);
    if (food == null || !mounted) return;
    await AppScope.of(context).meal.add(MealItem.fromFood(food, index.dataset.detailDefs));
  }

  Future<void> _clear() async {
    final store = AppScope.of(context).meal;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le repas ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Vider')),
        ],
      ),
    );
    if (ok == true) await store.clear();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).meal;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon repas'),
        actions: [
          IconButton(tooltip: 'Vider', icon: const Icon(Icons.delete_outline), onPressed: _clear),
        ],
      ),
      floatingActionButton: _index == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addFood,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            ),
      body: ValueListenableBuilder<List<MealItem>>(
        valueListenable: store,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return const MessageView(
              icon: Icons.restaurant_outlined,
              title: 'Repas vide',
              message: 'Ajoutez des aliments ou des produits scannés : Caillou additionne les valeurs '
                  'et propose de quoi compléter le repas.',
            );
          }
          final totals = MealTotals(items);
          final suggestions = _index == null ? const <MealSuggestion>[] : MealSuggester(_index!).suggest(items);
          final incomplete = totals.incompleteItems;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (final item in items) _ItemTile(item: item, onEdit: _editGrams, onRemove: (i) => store.remove(i.key)),
                ]),
              ),
              const SectionTitle('Total du repas'),
              NutritionTable(
                nutrition: totals.nutrition,
                basis: 'Pour ${totals.grams.round()} g',
                footnote: incomplete.isEmpty
                    ? null
                    : 'Total incomplet : certaines valeurs manquent pour ${incomplete.join(', ')}.',
              ),
              if (suggestions.isNotEmpty) ...[
                const SectionTitle('Pour compléter le repas'),
                for (final s in suggestions) _SuggestionCard(suggestion: s, store: store, index: _index!),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Suggestions indicatives calculées sur l\'appareil à partir des totaux, pas un avis médical.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.onEdit, required this.onRemove});

  final MealItem item;
  final ValueChanged<MealItem> onEdit;
  final ValueChanged<MealItem> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kcal = item.per100.energyKcal;
    final kcalText = kcal.value == null ? 'kcal n.d.' : '${(kcal.value! * item.grams / 100).round()} kcal';
    return ListTile(
      leading: Icon(item.isProduct ? Icons.inventory_2_outlined : Icons.eco_outlined, color: theme.colorScheme.primary),
      title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${item.grams.round()} g · $kcalText'),
      onTap: () => onEdit(item),
      trailing: IconButton(
        tooltip: 'Retirer',
        icon: const Icon(Icons.close),
        onPressed: () => onRemove(item),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.store, required this.index});

  final MealSuggestion suggestion;
  final MealStore store;
  final FoodIndex index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(suggestion.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text(suggestion.reason, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in suggestion.foods)
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text('${f.name.split(',').first} · ${f.nutrition.kcalLabel() ?? 'kcal n.d.'}/100 g'),
                onPressed: () => store.add(MealItem.fromFood(f, index.dataset.detailDefs, grams: suggestion.grams)),
              ),
          ]),
          const SizedBox(height: 4),
          Text('Ajouté avec ${suggestion.grams.round()} g, modifiable ensuite.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => FoodScreen(food: suggestion.foods.first)),
              ),
              child: Text('Voir « ${suggestion.foods.first.name.split(',').first} »'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Confirmation d'ajout avec raccourci vers le repas.
void showAddedToMeal(BuildContext context, String name) {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text('« $name » ajouté au repas.'),
    action: SnackBarAction(
      label: 'Voir le repas',
      onPressed: () => navigator.push(MaterialPageRoute<void>(builder: (_) => const MealScreen())),
    ),
  ));
}
