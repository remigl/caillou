import 'package:flutter/material.dart';

import '../../core/nutrients.dart';
import '../../core/reference_intakes.dart';
import '../../data/amino.dart';
import '../../data/ciqual/ciqual_food.dart';
import '../../services.dart';

/// Composition détaillée Ciqual (vitamines, minéraux, acides gras...), repliée par groupe.
class DetailedComposition extends StatelessWidget {
  const DetailedComposition({super.key, required this.food, required this.defs});

  final CiqualFood food;
  final List<DetailDef> defs;

  @override
  Widget build(BuildContext context) {
    const order = ['Glucides', 'Lipides', 'Minéraux et oligo-éléments', 'Vitamines', 'Autres'];
    final groups = <String, List<(DetailDef, NutrientValue)>>{for (final g in order) g: []};
    final sorted = [...food.details]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final (i, value) in sorted) {
      if (i >= defs.length) continue;
      final def = defs[i];
      groups.putIfAbsent(def.group, () => []).add((def, value));
    }
    groups.removeWhere((_, list) => list.isEmpty);
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
          PercentOfReference(value: value, unit: def.unit, label: def.name),
        ],
      ),
    );
  }
}

/// « 114 % VNR » à côté d'une vitamine ou d'un minéral ; en gras à partir de 15 % (quantité significative).
class PercentOfReference extends StatelessWidget {
  const PercentOfReference({super.key, required this.value, required this.unit, required this.label});

  final NutrientValue value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = percentOf(value, unit, nrvFor(label));
    if (p == null) return const SizedBox(width: 64);
    final theme = Theme.of(context);
    final strong = p >= kSignificantPercent;
    return SizedBox(
      width: 64,
      child: Text(
        formatPercent(p),
        textAlign: TextAlign.right,
        style: theme.textTheme.bodySmall?.copyWith(
          color: strong ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          fontWeight: strong ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
    );
  }
}

/// Légende commune des pourcentages de VNR.
class NrvLegend extends StatelessWidget {
  const NrvLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '% : part des valeurs nutritionnelles de référence (VNR, règlement UE 1169/2011). '
        'En gras : au moins 15 %, seuil d\'une « quantité significative ».',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// Acides aminés (USDA) : essentiels d'abord, leucine mise en avant (intérêt sportif).
class AminoSection extends StatefulWidget {
  const AminoSection({super.key, required this.ciqualCode});
  final int ciqualCode;

  @override
  State<AminoSection> createState() => _AminoSectionState();
}

class _AminoSectionState extends State<AminoSection> {
  Future<AminoProfile?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).amino.forCiqual(widget.ciqualCode);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AminoProfile?>(
      future: _future,
      builder: (context, snap) {
        final profile = snap.data;
        if (profile == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
        final essential = profile.values.where((v) => v.$2).toList();
        final others = profile.values.where((v) => !v.$2).toList();
        Widget row((String, bool, double) v) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(
                  child: Text(v.$1,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: v.$1 == 'Leucine' ? FontWeight.w700 : FontWeight.normal)),
                ),
                Text('${formatDecimal(v.$3)} g', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ]),
            );
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
            child: Text('Acides aminés (pour 100 g)',
                style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Container(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              ExpansionTile(
                title: const Text('Essentiels'),
                subtitle: Text('${essential.length} acides aminés', style: theme.textTheme.bodySmall),
                shape: const Border(),
                collapsedShape: const Border(),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [for (final v in essential) row(v)],
              ),
              if (others.isNotEmpty)
                ExpansionTile(
                  title: const Text('Non essentiels'),
                  subtitle: Text('${others.length} acides aminés', style: theme.textTheme.bodySmall),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [for (final v in others) row(v)],
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Source : USDA FoodData Central, SR Legacy (domaine public). Aliment américain le plus proche : '
              '« ${profile.usdaName} ». Valeurs d\'un aliment comparable, à titre indicatif.',
              style: muted,
            ),
          ),
        ]);
      },
    );
  }
}
