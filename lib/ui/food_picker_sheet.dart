import 'package:flutter/material.dart';

import '../data/ciqual/ciqual_food.dart';
import '../data/ciqual/food_index.dart';
import 'widgets/common.dart';

/// Feuille de sélection d'un aliment Ciqual (correction d'une reconnaissance photo).
Future<CiqualFood?> pickFood(BuildContext context, {required FoodIndex index, String initialQuery = ''}) {
  return showModalBottomSheet<CiqualFood>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _FoodPicker(index: index, initialQuery: initialQuery),
  );
}

class _FoodPicker extends StatefulWidget {
  const _FoodPicker({required this.index, required this.initialQuery});

  final FoodIndex index;
  final String initialQuery;

  @override
  State<_FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends State<_FoodPicker> {
  late final TextEditingController _query = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.index.search(_query.text, limit: 40);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _query,
                autofocus: widget.initialQuery.isEmpty,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Quel est cet aliment ?',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const MessageView(icon: Icons.search_off, title: 'Aucun aliment trouvé')
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) => FoodTile(
                        food: results[i],
                        onTap: () => Navigator.of(context).pop(results[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
