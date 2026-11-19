import 'package:caillou/core/nutrients.dart';
import 'package:caillou/ui/widgets/nutrition_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la fiche affiche les valeurs et signale les données absentes', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: NutritionTable(
          nutrition: Nutrition(
            energyKcal: NutrientValue.exact(52),
            carbohydrates: NutrientValue.exact(13.8),
            sugars: NutrientValue.exact(10.4),
            proteins: NutrientValue.exact(0.3),
            fat: NutrientValue.exact(0.2),
            fiber: NutrientValue.exact(2.4),
          ),
        ),
      ),
    ));

    expect(find.text('52'), findsOneWidget);
    expect(find.text('13,8 g'), findsOneWidget);
    expect(find.text('0,3 g'), findsOneWidget);
    // Sel, AG saturés et kJ non fournis.
    expect(find.text('Non disponible'), findsNWidgets(2));
  });
}
