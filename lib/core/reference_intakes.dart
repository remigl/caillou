/// Apports de référence (AR) et valeurs nutritionnelles de référence (VNR) d'un adulte-type,
/// règlement (UE) n° 1169/2011, annexe XIII. Texte réglementaire, librement réutilisable.
library;

import 'nutrients.dart';
import 'text.dart';

/// Valeur de référence avec son unité ("g", "mg", "µg", "kcal").
class Reference {
  const Reference(this.amount, this.unit);
  final double amount;
  final String unit;
}

/// Annexe XIII, partie B : énergie et macronutriments (par jour).
class MacroReferences {
  static const energyKcal = Reference(2000, 'kcal');
  static const fat = Reference(70, 'g');
  static const saturatedFat = Reference(20, 'g');
  static const carbohydrates = Reference(260, 'g');
  static const sugars = Reference(90, 'g');
  static const proteins = Reference(50, 'g');
  static const salt = Reference(6, 'g');
}

/// Annexe XIII, partie A : vitamines et minéraux (VNR). Clé = libellé normalisé (début du nom).
const List<(String, Reference)> _nrv = [
  ('activite vitaminique a', Reference(800, 'µg')),
  ('vitamine a', Reference(800, 'µg')),
  ('vitamine d', Reference(5, 'µg')),
  ('vitamine e', Reference(12, 'mg')),
  ('alpha tocopherol', Reference(12, 'mg')),
  ('vitamine k1', Reference(75, 'µg')),
  ('vitamine k', Reference(75, 'µg')),
  ('vitamine c', Reference(80, 'mg')),
  ('vitamine b1', Reference(1.1, 'mg')),
  ('vitamine b2', Reference(1.4, 'mg')),
  ('vitamine b3', Reference(16, 'mg')),
  ('vitamine b5', Reference(6, 'mg')),
  ('vitamine b6', Reference(1.4, 'mg')),
  ('vitamine b9 ou folates totaux', Reference(200, 'µg')),
  ('vitamine b9 (folates)', Reference(200, 'µg')),
  ('vitamine b12', Reference(2.5, 'µg')),
  ('potassium', Reference(2000, 'mg')),
  ('chlorure', Reference(800, 'mg')),
  ('calcium', Reference(800, 'mg')),
  ('phosphore', Reference(700, 'mg')),
  ('magnesium', Reference(375, 'mg')),
  ('fer', Reference(14, 'mg')),
  ('zinc', Reference(10, 'mg')),
  ('cuivre', Reference(1, 'mg')),
  ('manganese', Reference(2, 'mg')),
  ('selenium', Reference(55, 'µg')),
  ('iode', Reference(150, 'µg')),
];

/// Libellés qui ressemblent à une vitamine mais ne correspondent pas à une VNR
/// (formes partielles : vitamine D2/D3, folates DFE, K2...).
const List<String> _excluded = ['vitamine d2', 'vitamine d3', 'vitamine k2', 'dfe', 'folates intrinseques', 'acide folique'];

/// VNR pour un libellé Ciqual ou Open Food Facts ("Vitamine C", "Fer", "Vitamine B9 (folates)").
Reference? nrvFor(String label) {
  final n = normalizeText(label);
  if (_excluded.any((e) => n.contains(normalizeText(e)))) return null;
  for (final (key, ref) in _nrv) {
    final k = normalizeText(key);
    if (n == k || n.startsWith('$k ')) return ref;
  }
  return null;
}

double? _toUnit(double value, String from, String to) {
  const factors = {'g': 1.0, 'mg': 1e-3, 'µg': 1e-6, 'ug': 1e-6, 'kcal': 1.0};
  if (from == to) return value;
  final f = factors[from];
  final t = factors[to];
  if (f == null || t == null || from == 'kcal' || to == 'kcal') return null;
  return value * f / t;
}

/// Pourcentage de la référence (null si la valeur n'est pas un nombre exact ou si l'unité est incompatible).
double? percentOf(NutrientValue value, String unit, Reference? ref) {
  if (ref == null || value.kind != NutrientKind.exact) return null;
  final v = _toUnit(value.value!, unit, ref.unit);
  if (v == null) return null;
  return v / ref.amount * 100;
}

/// "12 %", "< 1 %", "114 %".
String formatPercent(double p) {
  if (p > 0 && p < 1) return '< 1 %';
  return '${p.round()} %';
}

/// Seuil d'une « quantité significative » pour les vitamines et minéraux : 15 % de la VNR pour 100 g
/// (annexe XIII, partie A, point 2).
const double kSignificantPercent = 15;

/// Quantité d'aliment apportant 10 g de glucides (repère utile pour compter les glucides).
/// Null si la teneur en glucides n'est pas un nombre exact d'au moins 1 g / 100 g.
double? gramsFor10gCarbs(NutrientValue carbohydrates) {
  if (carbohydrates.kind != NutrientKind.exact) return null;
  final c = carbohydrates.value!;
  if (c < 1) return null;
  return 10 / c * 100;
}
