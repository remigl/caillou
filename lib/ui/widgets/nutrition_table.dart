import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../core/nutrients.dart';

/// Tableau nutritionnel pour 100 g. Toute valeur absente est écrite « Non disponible ».
class NutritionTable extends StatelessWidget {
  const NutritionTable({super.key, required this.nutrition, this.basis = 'Pour 100 g'});

  final Nutrition nutrition;
  final String basis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kcal = nutrition.energyKcal.formatEnergy();
    final kj = nutrition.energyKj.formatEnergy();

    final energyNote = switch (nutrition.energySource) {
      EnergySource.direct => null,
      EnergySource.convertedFromKj => 'kcal calculées depuis les kJ (÷ 4,184)',
      EnergySource.ciqualJones => 'Énergie Ciqual calculée avec le facteur de Jones',
    };

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(basis.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1.1)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (kcal != null) ...[
                Text(kcal,
                    style: theme.textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
                const SizedBox(width: 6),
                Text('kcal', style: theme.textTheme.titleMedium),
              ] else
                Text('Énergie non disponible',
                    style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
              const Spacer(),
              if (kj != null) Text('$kj kJ', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
          if (energyNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(energyNote, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 10),
          Divider(height: 1, color: scheme.outlineVariant),
          _row(context, 'Lipides', nutrition.fat),
          _row(context, 'dont acides gras saturés', nutrition.saturatedFat, sub: true),
          _row(context, 'Glucides', nutrition.carbohydrates),
          _row(context, 'dont sucres', nutrition.sugars, sub: true),
          _row(context, 'Fibres', nutrition.fiber),
          _row(context, 'Protéines', nutrition.proteins),
          _row(context, 'Sel', nutrition.salt),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, NutrientValue value, {bool sub = false}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final amount = value.formatAmount();
    final labelStyle = sub
        ? theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)
        : theme.textTheme.bodyLarge;

    return Padding(
      padding: EdgeInsets.only(top: 10, left: sub ? 16 : 0),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          if (amount != null)
            Text(
              amount == 'traces' ? amount : '$amount g',
              style: (sub ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge)
                  ?.copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]),
            )
          else
            Text('Non disponible',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
