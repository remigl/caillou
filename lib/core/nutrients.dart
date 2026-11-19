/// Modèle commun des valeurs nutritionnelles (Open Food Facts et Ciqual).
///
/// Règle d'or : une valeur absente reste [NutrientValue.missing]. On n'affiche
/// jamais 0 à la place d'une donnée inconnue.
library;

enum NutrientKind { exact, lessThan, traces, missing }

class NutrientValue {
  const NutrientValue._(this.kind, this.value);

  const NutrientValue.exact(double v) : this._(NutrientKind.exact, v);
  const NutrientValue.lessThan(double v) : this._(NutrientKind.lessThan, v);
  static const traces = NutrientValue._(NutrientKind.traces, null);
  static const missing = NutrientValue._(NutrientKind.missing, null);

  final NutrientKind kind;
  final double? value;

  bool get isAvailable => kind != NutrientKind.missing;

  /// Valeur Ciqual telle qu'écrite dans l'asset JSON : nombre, "traces", "<0.5" ou null.
  factory NutrientValue.fromCiqual(Object? raw) {
    if (raw is num) return NutrientValue.exact(raw.toDouble());
    if (raw is String) {
      final s = raw.trim();
      if (s == 'traces') return traces;
      if (s.startsWith('<')) {
        final v = double.tryParse(s.substring(1).trim());
        if (v != null) return NutrientValue.lessThan(v);
      }
    }
    return missing;
  }

  /// Valeur Open Food Facts (`nutriments.xxx_100g`) : nombre ou chaîne numérique.
  factory NutrientValue.fromOff(Object? raw) {
    if (raw is num) {
      final d = raw.toDouble();
      return d.isFinite && d >= 0 ? NutrientValue.exact(d) : missing;
    }
    if (raw is String) {
      final d = double.tryParse(raw.trim().replaceAll(',', '.'));
      if (d != null && d.isFinite && d >= 0) return NutrientValue.exact(d);
    }
    return missing;
  }

  /// Texte affiché, sans unité ("13,8", "< 0,5", "traces"). Null si absent.
  String? formatAmount() {
    switch (kind) {
      case NutrientKind.exact:
        return formatDecimal(value!);
      case NutrientKind.lessThan:
        return '< ${formatDecimal(value!)}';
      case NutrientKind.traces:
        return 'traces';
      case NutrientKind.missing:
        return null;
    }
  }

  /// Énergie : arrondie à l'unité.
  String? formatEnergy() {
    switch (kind) {
      case NutrientKind.exact:
        return value!.round().toString();
      case NutrientKind.lessThan:
        return '< ${value!.round()}';
      case NutrientKind.traces:
        return '0';
      case NutrientKind.missing:
        return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is NutrientValue && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => 'NutrientValue($kind, $value)';
}

/// Format français : virgule décimale, 1 décimale au-delà de 10, 2 en dessous, zéros inutiles retirés.
String formatDecimal(double v) {
  final fixed = v.abs() >= 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(2);
  var s = fixed;
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return s.replaceAll('.', ',');
}

/// Comment l'énergie a été obtenue (affiché sous la valeur quand ce n'est pas la valeur directe).
enum EnergySource {
  /// Valeur fournie telle quelle par la source.
  direct,

  /// Open Food Facts ne donnait que les kJ : kcal = kJ / 4,184.
  convertedFromKj,

  /// Ciqual : énergie « N x facteur de Jones, avec fibres » (autre calcul officiel de l'Anses).
  ciqualJones,
}

class Nutrition {
  const Nutrition({
    this.energyKcal = NutrientValue.missing,
    this.energyKj = NutrientValue.missing,
    this.fat = NutrientValue.missing,
    this.saturatedFat = NutrientValue.missing,
    this.carbohydrates = NutrientValue.missing,
    this.sugars = NutrientValue.missing,
    this.fiber = NutrientValue.missing,
    this.proteins = NutrientValue.missing,
    this.salt = NutrientValue.missing,
    this.energySource = EnergySource.direct,
  });

  final NutrientValue energyKcal;
  final NutrientValue energyKj;
  final NutrientValue fat;
  final NutrientValue saturatedFat;
  final NutrientValue carbohydrates;
  final NutrientValue sugars;
  final NutrientValue fiber;
  final NutrientValue proteins;
  final NutrientValue salt;
  final EnergySource energySource;

  List<NutrientValue> get _all => [
        energyKcal,
        energyKj,
        fat,
        saturatedFat,
        carbohydrates,
        sugars,
        fiber,
        proteins,
        salt,
      ];

  bool get isEmpty => _all.every((v) => !v.isAvailable);
  bool get hasMissing => _all.any((v) => !v.isAvailable);

  /// Résumé court pour les listes : "P 0,3 · G 13,8 · L 0,2 · F 2,4".
  String shortMacros() {
    String part(String label, NutrientValue v) => '$label ${v.formatAmount() ?? '–'}';
    return [
      part('P', proteins),
      part('G', carbohydrates),
      part('L', fat),
      if (fiber.isAvailable) part('F', fiber),
    ].join(' · ');
  }

  /// "52 kcal" ou null.
  String? kcalLabel() {
    final e = energyKcal.formatEnergy();
    return e == null ? null : '$e kcal';
  }
}
