import '../core/text.dart';
import 'ciqual/food_index.dart';

/// Un aliment « canonique » : la couche de normalisation entre ce que renvoie la
/// reconnaissance d'image (souvent un nom anglais ou générique) et la table Ciqual.
class CanonicalFood {
  const CanonicalFood(
    this.name,
    this.emoji, {
    this.aliases = const [],
    this.query,
    this.prefer = PreferredState.raw,
  });

  /// Nom français affiché ("pomme").
  final String name;
  final String emoji;

  /// Synonymes français et noms anglais ("apple", "red apple"...). Pluriels gérés automatiquement.
  final List<String> aliases;

  /// Requête Ciqual si différente du nom ("pates alimentaires").
  final String? query;

  /// Préparation par défaut quand la photo ne permet pas de trancher.
  final PreferredState prefer;

  String get ciqualQuery => query ?? name;
}

/// Alias et synonymes. Volontairement simple : une liste lisible, facile à compléter.
class FoodAliases {
  static const PreferredState _cooked = PreferredState.cooked;

  static const List<CanonicalFood> all = [
    // Fruits
    CanonicalFood('pomme', '🍎', aliases: ['apple', 'red apple', 'green apple', 'pomme rouge', 'pomme verte']),
    CanonicalFood('banane', '🍌', aliases: ['banana']),
    CanonicalFood('orange', '🍊', aliases: ['orange fruit']),
    CanonicalFood('clémentine', '🍊', aliases: ['clementine', 'mandarine', 'mandarin', 'tangerine']),
    CanonicalFood('citron', '🍋', aliases: ['lemon']),
    CanonicalFood('citron vert', '🍋', aliases: ['lime']),
    CanonicalFood('pamplemousse', '🍊', aliases: ['grapefruit', 'pomelo']),
    CanonicalFood('poire', '🍐', aliases: ['pear']),
    CanonicalFood('pêche', '🍑', aliases: ['peach', 'nectarine', 'brugnon']),
    CanonicalFood('abricot', '🍑', aliases: ['apricot']),
    CanonicalFood('prune', '🍑', aliases: ['plum', 'mirabelle']),
    CanonicalFood('cerise', '🍒', aliases: ['cherry', 'cherries']),
    CanonicalFood('fraise', '🍓', aliases: ['strawberry', 'strawberries']),
    CanonicalFood('framboise', '🫐', aliases: ['raspberry', 'raspberries']),
    CanonicalFood('myrtille', '🫐', aliases: ['blueberry', 'blueberries', 'bleuet']),
    CanonicalFood('raisin', '🍇', aliases: ['grape', 'grapes', 'raisin blanc', 'raisin noir']),
    CanonicalFood('kiwi', '🥝', aliases: ['kiwifruit', 'kiwi fruit']),
    CanonicalFood('ananas', '🍍', aliases: ['pineapple']),
    CanonicalFood('mangue', '🥭', aliases: ['mango']),
    CanonicalFood('melon', '🍈', aliases: ['cantaloupe', 'honeydew']),
    CanonicalFood('pastèque', '🍉', aliases: ['watermelon']),
    CanonicalFood('figue', '🍈', aliases: ['fig']),
    CanonicalFood('grenade', '🍎', aliases: ['pomegranate']),
    CanonicalFood('noix de coco', '🥥', aliases: ['coconut', 'coco']),
    CanonicalFood('datte', '🌴', aliases: ['date', 'dates', 'date fruit']),
    CanonicalFood('avocat', '🥑', aliases: ['avocado']),
    // Légumes
    CanonicalFood('brocoli', '🥦', aliases: ['broccoli', 'brocolis']),
    CanonicalFood('carotte', '🥕', aliases: ['carrot', 'baby carrot']),
    CanonicalFood('tomate', '🍅', aliases: ['tomato', 'tomatoes']),
    CanonicalFood('tomate cerise', '🍅', aliases: ['cherry tomato', 'cherry tomatoes']),
    CanonicalFood('concombre', '🥒', aliases: ['cucumber']),
    CanonicalFood('courgette', '🥒', aliases: ['zucchini', 'courgette']),
    CanonicalFood('aubergine', '🍆', aliases: ['eggplant', 'aubergine']),
    CanonicalFood('poivron', '🫑', aliases: ['bell pepper', 'pepper', 'sweet pepper', 'red pepper', 'green pepper']),
    CanonicalFood('piment', '🌶️', aliases: ['chili', 'chili pepper', 'hot pepper']),
    CanonicalFood('oignon', '🧅', aliases: ['onion', 'red onion']),
    CanonicalFood('échalote', '🧅', aliases: ['shallot']),
    CanonicalFood('ail', '🧄', aliases: ['garlic']),
    CanonicalFood('pomme de terre', '🥔', aliases: ['potato', 'potatoes', 'patate'], prefer: _cooked),
    CanonicalFood('patate douce', '🍠', aliases: ['sweet potato'], prefer: _cooked),
    CanonicalFood('champignon', '🍄', aliases: ['mushroom', 'champignon de paris', 'button mushroom']),
    CanonicalFood('laitue', '🥬', aliases: ['lettuce', 'salade', 'salad greens']),
    CanonicalFood('épinard', '🥬', aliases: ['spinach']),
    CanonicalFood('chou', '🥬', aliases: ['cabbage']),
    CanonicalFood('chou-fleur', '🥦', aliases: ['cauliflower', 'chou fleur']),
    CanonicalFood('chou de bruxelles', '🥬', aliases: ['brussels sprout', 'brussels sprouts']),
    CanonicalFood('haricot vert', '🫛', aliases: ['green bean', 'green beans', 'string bean']),
    CanonicalFood('petit pois', '🫛', aliases: ['pea', 'peas', 'green peas']),
    CanonicalFood('maïs', '🌽', aliases: ['corn', 'sweet corn', 'mais']),
    CanonicalFood('radis', '🌱', aliases: ['radish']),
    CanonicalFood('betterave', '🌱', aliases: ['beet', 'beetroot']),
    CanonicalFood('poireau', '🌱', aliases: ['leek']),
    CanonicalFood('céleri', '🌱', aliases: ['celery']),
    CanonicalFood('asperge', '🌱', aliases: ['asparagus']),
    CanonicalFood('artichaut', '🌱', aliases: ['artichoke']),
    CanonicalFood('potiron', '🎃', aliases: ['pumpkin', 'citrouille', 'courge', 'squash', 'butternut']),
    CanonicalFood('olive', '🫒', aliases: ['olives']),
    // Féculents, légumineuses
    CanonicalFood('riz', '🍚', aliases: ['rice', 'white rice', 'riz blanc'], prefer: _cooked),
    CanonicalFood('pâtes', '🍝', aliases: ['pasta', 'spaghetti', 'penne', 'macaroni'], query: 'pates alimentaires', prefer: _cooked),
    CanonicalFood('pain', '🍞', aliases: ['bread', 'baguette'], prefer: PreferredState.any),
    CanonicalFood('lentille', '🫘', aliases: ['lentil', 'lentils'], prefer: _cooked),
    CanonicalFood('pois chiche', '🫘', aliases: ['chickpea', 'chickpeas'], prefer: _cooked),
    CanonicalFood('haricot rouge', '🫘', aliases: ['kidney bean', 'red beans'], prefer: _cooked),
    CanonicalFood('quinoa', '🌾', aliases: ['quinoa'], prefer: _cooked),
    CanonicalFood('flocons d\'avoine', '🌾', aliases: ['oats', 'oatmeal', 'rolled oats', 'avoine'], query: 'avoine', prefer: PreferredState.any),
    // Protéines animales, produits laitiers
    CanonicalFood('œuf', '🥚', aliases: ['egg', 'eggs', 'oeuf'], query: 'oeuf', prefer: PreferredState.any),
    CanonicalFood('poulet', '🍗', aliases: ['chicken', 'chicken breast', 'chicken leg'], prefer: _cooked),
    CanonicalFood('bœuf', '🥩', aliases: ['beef', 'steak', 'boeuf'], query: 'boeuf', prefer: _cooked),
    CanonicalFood('porc', '🥓', aliases: ['pork'], prefer: _cooked),
    CanonicalFood('jambon', '🥓', aliases: ['ham'], prefer: PreferredState.any),
    CanonicalFood('saumon', '🐟', aliases: ['salmon'], prefer: _cooked),
    CanonicalFood('thon', '🐟', aliases: ['tuna'], prefer: PreferredState.any),
    CanonicalFood('crevette', '🦐', aliases: ['shrimp', 'prawn'], prefer: _cooked),
    CanonicalFood('fromage', '🧀', aliases: ['cheese'], prefer: PreferredState.any),
    CanonicalFood('lait', '🥛', aliases: ['milk'], prefer: PreferredState.any),
    CanonicalFood('yaourt', '🥛', aliases: ['yogurt', 'yoghurt', 'yogourt'], prefer: PreferredState.any),
    CanonicalFood('beurre', '🧈', aliases: ['butter'], prefer: PreferredState.any),
    // Fruits à coque
    CanonicalFood('noix', '🌰', aliases: ['walnut', 'walnuts']),
    CanonicalFood('amande', '🌰', aliases: ['almond', 'almonds']),
    CanonicalFood('noisette', '🌰', aliases: ['hazelnut', 'hazelnuts']),
    CanonicalFood('cacahuète', '🥜', aliases: ['peanut', 'peanuts', 'arachide', 'cacahouete'], prefer: PreferredState.any),
    CanonicalFood('chocolat', '🍫', aliases: ['chocolate'], prefer: PreferredState.any),
  ];

  /// Clés exactes (sans accents, sans retrait des pluriels) : "pates" ≠ "pate" (pâté).
  static final Map<String, CanonicalFood> _exact = _buildIndex(normalizeText);

  /// Clés tolérantes (pluriels retirés) : "carrots" -> "carrot".
  static final Map<String, CanonicalFood> _loose = _buildIndex(phraseKey);

  static Map<String, CanonicalFood> _buildIndex(String Function(String) keyOf) {
    final map = <String, CanonicalFood>{};
    for (final f in all) {
      map.putIfAbsent(keyOf(f.name), () => f);
      for (final a in f.aliases) {
        map.putIfAbsent(keyOf(a), () => f);
      }
    }
    return map;
  }

  /// "Broccoli", "brocolis", "Brocoli" -> brocoli. Null si inconnu.
  static CanonicalFood? lookup(String? name) {
    if (name == null) return null;
    final exact = normalizeText(name);
    if (exact.isEmpty) return null;
    return _exact[exact] ?? _loose[phraseKey(name)];
  }

  /// Requête supplémentaire pour la recherche Ciqual : "broccoli" -> "brocoli", "pâtes" -> "pates alimentaires".
  /// Correspondance exacte uniquement, pour ne pas transformer « pâté » en « pâtes ».
  static String? expansionFor(String query) {
    final n = normalizeText(query);
    final canonical = _exact[n];
    if (canonical == null) return null;
    final q = normalizeText(canonical.ciqualQuery);
    return q == n ? null : q;
  }
}
