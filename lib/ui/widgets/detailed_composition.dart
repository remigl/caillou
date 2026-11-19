import 'package:flutter/material.dart';

import '../../core/nutrients.dart';
import '../../data/ciqual/ciqual_food.dart';

/// Composition détaillée Ciqual (vitamines, minéraux, acides gras...), repliée par groupe.
class DetailedComposition extends StatelessWidget {
  const DetailedComposition({super.key, required this.food, required this.defs});

  final CiqualFood food;
  final List<DetailDef> defs;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<(DetailDef, NutrientValue)>>{};
    for (final (i, value) in food.details) {
      if (i >= defs.length) continue;
      final def = defs[i];
      groups.putIfAbsent(def.group, () => []).add((def, value));
    }
    if (groups.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final entry in groups.entries)
            ExpansionTile(
              title: Text(entry.key),
              subtitle: Text('${entry.value.length} valeur${entry.value.length > 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall),
              shape: const Border(),
              collapsedShape: const Border(),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                for (final (def, value) in entry.value) _DetailRow(def: def, value: value),
              ],
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.def, required this.value});

  final DetailDef def;
  final NutrientValue value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = value.formatAmount() ?? '';
    final text = amount == 'traces' ? amount : '$amount ${def.unit}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(def.name, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 12),
          Text(text, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
