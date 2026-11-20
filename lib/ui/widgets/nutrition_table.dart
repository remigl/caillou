import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../core/nutrients.dart';
import '../../core/reference_intakes.dart';

/// Tableau nutritionnel pour 100 g. Toute valeur absente est écrite « Non disponible ».
/// Colonne « % AR » : part des apports de référence d'un adulte-type (règlement UE 1169/2011).
class NutritionTable extends StatelessWidget {
  const NutritionTable({
    super.key,
    required this.nutrition,
    this.basis = 'Pour 100 g',
    this.showReference = true,
    this.footnote,
  });

  final Nutrition nutrition;
  final String basis;
  final bool showReference;

  /// Note affichée sous le tableau (ex. totaux incomplets).
  final String? footnote;

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
              if (showReference && percentOf(nutrition.energyKcal, 'kcal', MacroReferences.energyKcal) != null) ...[
                const SizedBox(width: 10),
                _percentBadge(context, percentOf(nutrition.energyKcal, 'kcal', MacroReferences.energyKcal)!),
              ],
            ],
          ),
          if (energyNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(energyNote, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 10),
          Divider(height: 1, color: scheme.outlineVariant),
          _row(context, 'Lipides', nutrition.fat, ref: MacroReferences.fat),
          _row(context, 'dont acides gras saturés', nutrition.saturatedFat, sub: true, ref: MacroReferences.saturatedFat),
          _row(context, 'Glucides', nutrition.carbohydrates, ref: MacroReferences.carbohydrates),
          _row(context, 'dont sucres', nutrition.sugars, sub: true, ref: MacroReferences.sugars),
          _row(context, 'Fibres', nutrition.fiber),
          _row(context, 'Protéines', nutrition.proteins, ref: MacroReferences.proteins),
          _row(context, 'Sel', nutrition.salt, ref: MacroReferences.salt),
          if (showReference) ...[
            const SizedBox(height: 10),
            Text('% AR : part des apports de référence quotidiens d\'un adulte-type (8400 kJ / 2000 kcal).',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          if (footnote != null) ...[
            const SizedBox(height: 6),
            Text(footnote!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  Widget _percentBadge(BuildContext context, double p) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 48,
      child: Text(
        formatPercent(p),
        textAlign: TextAlign.right,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, NutrientValue value, {bool sub = false, Reference? ref}) {
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
          if (showReference)
            percentOf(value, 'g', ref) == null
                ? const SizedBox(width: 48)
                : _percentBadge(context, percentOf(value, 'g', ref)!),
        ],
      ),
    );
  }
}

/// Repère pour compter les glucides : quantité d'aliment qui apporte 10 g de glucides.
class CarbReference extends StatelessWidget {
  const CarbReference({super.key, required this.nutrition, this.liquid = false});

  final Nutrition nutrition;
  final bool liquid;

  @override
  Widget build(BuildContext context) {
    final carbs = nutrition.carbohydrates;
    if (carbs.kind == NutrientKind.missing) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final grams = gramsFor10gCarbs(carbs);
    final unit = liquid ? 'ml' : 'g';
    final String text;
    if (grams == null) {
      text = 'Moins de 1 g de glucides pour 100 $unit.';
    } else if (grams >= 1000) {
      final big = (grams / 1000).toStringAsFixed(1).replaceAll('.', ',');
      text = '10 g de glucides ≈ $big ${liquid ? 'l' : 'kg'} de cet aliment.';
    } else {
      text = '10 g de glucides ≈ ${grams.round()} $unit de cet aliment.';
    }
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(Icons.grain, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ]),
    );
  }
}
