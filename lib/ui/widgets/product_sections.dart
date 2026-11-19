import 'package:flutter/material.dart';

import '../../data/additives.dart';
import '../../data/ciqual/ciqual_food.dart';
import '../../data/cross_reference.dart';
import '../../data/off/off_product.dart';
import '../../data/off/open_prices.dart';
import '../../services.dart';
import '../food_screen.dart';
import 'common.dart';

/// Bloc arrondi commun aux sections de la fiche produit.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.color, this.icon});
  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withAlpha(30),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 16, color: c), const SizedBox(width: 6)],
        Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurface)),
      ]),
    );
  }
}

const _green = Color(0xFF2E8B57);
const _orange = Color(0xFFE08A00);
const _red = Color(0xFFD64531);

/// Repères Open Food Facts (faible / modéré / élevé) pour lipides, AG saturés, sucres, sel.
class NutrientLevels extends StatelessWidget {
  const NutrientLevels({super.key, required this.levels});
  final Map<String, String> levels;

  @override
  Widget build(BuildContext context) {
    const labels = {'fat': 'Lipides', 'saturated-fat': 'AG saturés', 'sugars': 'Sucres', 'salt': 'Sel'};
    const words = {'low': 'faible', 'moderate': 'modéré', 'high': 'élevé'};
    const colors = {'low': _green, 'moderate': _orange, 'high': _red};
    final entries = labels.entries.where((e) => levels.containsKey(e.key)).toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in entries)
            _Pill('${e.value} : ${words[levels[e.key]]}', color: colors[levels[e.key]], icon: Icons.circle),
        ]),
        const SizedBox(height: 6),
        Text('Repères pour 100 g calculés par Open Food Facts (seuils de l\'agence britannique FSA).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

/// Végétalien / végétarien / huile de palme, d'après l'analyse des ingrédients.
class IngredientsAnalysis extends StatelessWidget {
  const IngredientsAnalysis({super.key, required this.product});
  final OffProduct product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final pills = <Widget>[
      if (p.vegan != Tri.unknown) _tri('Végétalien', p.vegan),
      if (p.vegetarian != Tri.unknown) _tri('Végétarien', p.vegetarian),
      if (p.palmOil == Tri.yes) const _Pill('Contient de l\'huile de palme', color: _orange, icon: Icons.water_drop),
      if (p.palmOil == Tri.no) const _Pill('Sans huile de palme', color: _green, icon: Icons.check),
      if (p.palmOil == Tri.maybe) const _Pill('Huile de palme possible', color: _orange, icon: Icons.help_outline),
    ];
    if (pills.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(spacing: 8, runSpacing: 8, children: pills),
    );
  }

  static Widget _tri(String label, Tri t) => switch (t) {
        Tri.yes => _Pill(label, color: _green, icon: Icons.check),
        Tri.no => _Pill('Non ${label.toLowerCase()}', icon: Icons.close),
        Tri.maybe => _Pill('$label ?', color: _orange, icon: Icons.help_outline),
        Tri.unknown => const SizedBox.shrink(),
      };
}

/// Additifs avec leur nom et leur rôle (taxonomie Open Food Facts).
class AdditivesSection extends StatefulWidget {
  const AdditivesSection({super.key, required this.codes});
  final List<String> codes;

  @override
  State<AdditivesSection> createState() => _AdditivesSectionState();
}

class _AdditivesSectionState extends State<AdditivesSection> {
  Future<List<AdditiveInfo>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).additives.describe(widget.codes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.codes.isEmpty) {
      return Text('Aucun additif renseigné.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic));
    }
    return FutureBuilder<List<AdditiveInfo>>(
      future: _future,
      builder: (context, snap) {
        final list = snap.data ??
            widget.codes.map((c) => AdditiveInfo(AdditiveDatabase.formatCode(c), null, null)).toList();
        return Panel(
          child: Column(children: [
            for (final a in list)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 64, child: Text(a.code, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.name ?? 'Nom non disponible', style: theme.textTheme.bodyMedium),
                      if (a.role != null)
                        Text(a.role!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ]),
                  ),
                ]),
              ),
          ]),
        );
      },
    );
  }
}

/// Nutriments supplémentaires déclarés pour le produit (vitamines, minéraux...).
class ExtraNutrientsPanel extends StatelessWidget {
  const ExtraNutrientsPanel({super.key, required this.extras});
  final List<ExtraNutrient> extras;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      child: Column(children: [
        for (final e in extras)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Expanded(child: Text(e.label, style: theme.textTheme.bodyMedium)),
              Text('${e.value.formatAmount()} ${e.unit}',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
      ]),
    );
  }
}

/// Score environnemental et impact climat (Agribalyse via Open Food Facts).
class EnvironmentPanel extends StatelessWidget {
  const EnvironmentPanel({super.key, required this.product});
  final OffProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grade = product.environmentalGrade;
    final co2 = product.co2PerKg;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (grade != null)
          Row(children: [
            Expanded(child: Text('Score environnemental', style: theme.textTheme.bodyLarge)),
            _Pill(grade == 'a-plus' ? 'A+' : grade.toUpperCase(), color: _gradeColor(grade)),
          ]),
        if (co2 != null) ...[
          if (grade != null) const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text('Impact climat de la catégorie', style: theme.textTheme.bodyLarge)),
            Text('${_kg(co2)} kg CO₂e / kg', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          ]),
        ],
        const SizedBox(height: 8),
        Text('Score calculé par Open Food Facts à partir de la base Agribalyse (ADEME), '
            'ajusté selon l\'origine, l\'emballage et les labels.', style: muted),
      ]),
    );
  }

  static String _kg(double v) => (v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)).replaceAll('.', ',');

  static Color _gradeColor(String g) => switch (g) {
        'a-plus' || 'a' || 'b' => _green,
        'c' => _orange,
        _ => _red,
      };
}

/// Aliment générique Ciqual comparable : ouvre la composition détaillée (vitamines, minéraux).
class GenericEquivalentCard extends StatefulWidget {
  const GenericEquivalentCard({super.key, required this.product});
  final OffProduct product;

  @override
  State<GenericEquivalentCard> createState() => _GenericEquivalentCardState();
}

class _GenericEquivalentCardState extends State<GenericEquivalentCard> {
  Future<CiqualFood?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= () async {
      try {
        final index = await AppScope.of(context).foods.load();
        return genericEquivalent(widget.product, index);
      } catch (_) {
        return null;
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CiqualFood?>(
      future: _future,
      builder: (context, snap) {
        final food = snap.data;
        if (food == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Aliment générique comparable'),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(Icons.science_outlined, color: theme.colorScheme.primary),
              title: Text(food.name),
              subtitle: Text(
                'Table Ciqual (Anses) : vitamines, minéraux, acides gras… '
                'Valeurs moyennes d\'un aliment comparable, pas celles de ce produit.',
                style: theme.textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FoodScreen(food: food))),
            ),
          ),
        ]);
      },
    );
  }
}

/// Derniers prix relevés par la communauté (Open Prices).
class PricesSection extends StatefulWidget {
  const PricesSection({super.key, required this.barcode});
  final String barcode;

  @override
  State<PricesSection> createState() => _PricesSectionState();
}

class _PricesSectionState extends State<PricesSection> {
  Future<List<PriceObservation>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).prices.latest(widget.barcode);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PriceObservation>>(
      future: _future,
      builder: (context, snap) {
        final prices = snap.data ?? const [];
        if (prices.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Prix relevés'),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final p in prices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: 92,
                      child: Text('${formatPrice(p.price, p.currency)}${p.perKilo ? '/kg' : ''}',
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Expanded(
                      child: Text(
                        [
                          if (p.place != null) p.place!,
                          if (p.date != null) _date(p.date!),
                          if (p.discounted) 'promotion',
                        ].join(' · '),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ]),
                ),
              const SizedBox(height: 6),
              Text('Relevés par des contributeurs d\'Open Prices (Open Food Facts).', style: muted),
            ]),
          ),
        ]);
      },
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
