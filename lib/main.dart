import 'package:flutter/material.dart';

import 'app.dart';
import 'services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await Services.create();
  // Préchargement de la table Ciqual en arrière-plan : la recherche est instantanée ensuite.
  services.foods.load().ignore();
  runApp(CaillouApp(services: services));
}
