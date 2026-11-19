# Caillou — analyse et architecture du MVP

## 1. Besoins, ramenés à l'essentiel

| Fonction | Entrée | Source des données | Sortie |
|---|---|---|---|
| A. Scan | code-barres EAN/UPC | Open Food Facts (API) | fiche produit + nutrition / 100 g |
| B. Recherche | texte (« brocoli ») | table Ciqual 2025 embarquée | liste d'aliments génériques / 100 g |
| C. Photo | une photo, plusieurs aliments | modèle de vision → Ciqual | liste « aliment — confiance — kcal / 100 g » |

Hors périmètre (volontairement) : quantités, poids, calories d'une assiette, compte, social,
abonnement, conseils médicaux, score maison.

## 2. Problèmes techniques et juridiques identifiés

**Données**
- Open Food Facts est **collaboratif** : produits absents, champs vides, erreurs possibles.
  → chaque champ peut être « Non disponible » ; aucune valeur n'est complétée ou devinée.
- La recherche plein texte d'Open Food Facts n'est pas adaptée (10 requêtes/min, interdite en
  « recherche à la frappe ») et renvoie des produits de marque, pas « brocoli cru ».
  → la recherche d'aliments génériques se fait **hors ligne** dans la table Ciqual.
- L'API Open Food Facts v3.5 change la structure des nutriments (encore en développement).
  → l'app fige **`/api/v3.4/`**, version v3 stable qui conserve `nutriments.*_100g`.
- Ciqual contient des valeurs « traces », « < 0,5 » et des absences (« - ») : elles sont
  conservées telles quelles et affichées comme telles, jamais converties en 0.
- Énergie Ciqual : quand la valeur « règlement UE 1169/2011 » manque, on prend la valeur
  « N × facteur de Jones, avec fibres » publiée par l'Anses (signalée sous le chiffre).
- Cru / cuit : les valeurs pour 100 g changent fortement (eau). Les fiches affichent l'état,
  proposent les autres préparations, et la photo choisit « cru » par défaut pour les fruits et
  légumes, « cuit » pour riz, pâtes, légumineuses, viandes, sauf si le modèle voit l'inverse.

**Reconnaissance d'image**
- Un modèle généraliste (classification ImageNet/COCO) ne connaît qu'une dizaine d'aliments
  (COCO : pomme, banane, brocoli, carotte… mais pas la tomate). Un modèle de vision-langage
  reconnaît n'importe quel aliment, en plusieurs exemplaires, et répond directement en JSON.
- La « confiance » d'un modèle de vision-langage est **auto-déclarée**, pas une probabilité
  calibrée. Elle sert de signal (seuil 60 %) et l'utilisateur peut toujours corriger.
- Une clé d'API embarquée dans un APK est extractible en quelques minutes.

**Juridique**
- Open Food Facts : ODbL (base), DbCL (contenu), CC BY-SA (photos) → attribution affichée sur
  chaque fiche ; pas de redistribution d'une base dérivée sans la même licence (le cache local
  n'est pas redistribué). User-Agent identifiant obligatoire.
- Ciqual : Licence Ouverte 2.0 → réutilisation libre, y compris commerciale, avec mention de la
  source et de la date. Mention présente sur chaque fiche et dans les réglages.
- Yuka : aucune donnée, aucun visuel, aucun nom ni score repris. Pas de note sur 100, pas de
  pastille colorée « bon/mauvais » : seulement les valeurs officielles et deux indicateurs
  publics (Nutri-Score, NOVA) affichés en texte, sans reproduire leurs logos.
- Nutri-Score est une marque (Santé publique France) : on affiche la lettre fournie par
  Open Food Facts, sans le logo officiel. Avant une publication sur un store, relire le
  règlement d'usage de la marque.
- Photos envoyées au fournisseur de vision : uniquement à l'initiative de l'utilisateur ; à
  mentionner dans une politique de confidentialité avant toute diffusion publique (RGPD). Vérifier
  les conditions du fournisseur (usage des données pour l'entraînement selon l'offre).
- Pas d'avis médical : mention sur les fiches et dans les réglages.

## 3. Stack choisie

| Besoin | Choix | Pourquoi |
|---|---|---|
| App mobile | **Flutter** (Dart), Android d'abord | une base de code, bon rendu, déjà utilisé sur tes autres projets ; iOS possible ensuite |
| Code-barres | `mobile_scanner` | le plus maintenu ; lecture continue de l'aperçu caméra |
| Photo | `image_picker` | appareil photo natif + galerie, redimensionnement intégré (1280 px) |
| Réseau | `http` | suffit, pas de client lourd |
| Stockage local | `shared_preferences` | historique, cache produits (100), réglages |
| Aliments génériques | JSON Ciqual embarqué (~1 Mo) | hors ligne, instantané, aucune limite d'API |
| Vision | API « Chat Completions » avec image, configurable | voir § 5 |
| CI | GitHub Actions | APK construit et publié à chaque push, testable depuis le téléphone |

Pas de gestion d'état externe (Provider, Riverpod…) : `StatefulWidget` + `FutureBuilder` et un
`InheritedWidget` (`AppScope`) pour les services. Quatre dépendances au total.

## 4. Faut-il un backend ?

- **Scan (A)** : non. L'API Open Food Facts est publique, sans clé ; l'app l'appelle directement.
- **Recherche (B)** : non. La table Ciqual est embarquée dans l'app.
- **Photo (C)** : pas pour un usage personnel. La clé peut être saisie dans l'app (elle reste
  dans le stockage privé du téléphone, sauvegarde Android désactivée, jamais dans le dépôt ni
  l'APK). **Dès que l'app est distribuée**, un mini-proxy devient nécessaire pour garder la clé
  côté serveur : il est fourni dans `proxy/` (Cloudflare Worker, ~60 lignes, sans dépendance).
  L'app ne change pas : seules l'adresse et le jeton changent dans les réglages.

## 5. Reconnaissance d'image : options

| Option | Qualité multi-aliments | Vie privée / libre | Complexité | Coût |
|---|---|---|---|---|
| **Modèle de vision-langage via API compatible** (Mistral, ou Ollama local, ou proxy) | très bonne, tout aliment | photo envoyée au service choisi ; modèles à poids ouverts possibles | faible | quelques centimes / centaine de photos, ou 0 en local |
| Détecteur embarqué (TFLite COCO) | ~10 aliments seulement | 100 % local | moyenne | 0 |
| Classifieur zéro-shot embarqué (SigLIP + étiquettes Ciqual) | correcte, multi-étiquettes | 100 % local, libre | élevée (conversion, ~100 Mo) | 0 |

**Choix MVP : la première**, derrière une interface `FoodRecognizer`. Le client parle le format
« Chat Completions » (le plus répandu) : Mistral (`mistral-small-latest`, modèles à poids ouverts,
hébergement européen), un modèle libre sur ton PC via Ollama (ex. `qwen2.5vl:7b`, exposé en HTTPS
avec `tailscale serve`), ou le proxy. Un moteur 100 % embarqué pourra remplacer
`RemoteVisionRecognizer` sans toucher aux écrans.

Le modèle reçoit une consigne stricte (aliments distincts, pas de quantités, JSON uniquement,
nom FR + EN, état cru/cuit, confiance honnête). Si la confiance manque, elle vaut 0 → « à vérifier ».

## 6. Flux et couches

```
UI (lib/ui)                     Données (lib/data)                     Externe
───────────                     ──────────────────                     ───────
ScannerScreen ─► ProductScreen ─► OffRepository ─► ProductCache (local)
                                      └──────────► OffApi ───────────► Open Food Facts v3.4
HomeScreen ─► SearchResults ────► FoodDatabase ─► FoodIndex ─► ciqual.json (asset)
PhotoScreen ─► RemoteVisionRecognizer ───────────────────────────────► API vision / proxy
          └──► FoodMatcher ─► FoodAliases (normalisation) ─► FoodIndex
```

**Cache.** Produit : cache d'abord (7 jours), réseau ensuite ; en cas d'échec réseau ou de
limite atteinte, la copie locale est servie avec la mention « hors ligne ». 100 produits max
(LRU). Ciqual : chargé une fois au démarrage, en arrière-plan (isolate).

**Erreurs réseau.** Délais (12 s Open Food Facts, 60 s vision), erreurs typées
(`OffNetworkError`, `OffRateLimited`, `OffProductNotFound`, `RecognitionException`…) traduites en
messages clairs avec bouton « Réessayer ». Le 404 d'Open Food Facts = produit introuvable.
Si le serveur de vision refuse `response_format`, un second essai est fait sans.

**Normalisation reconnaissance → nutrition.** `"broccoli"` → alias → aliment canonique
`brocoli` (emoji, préparation par défaut) → recherche Ciqual tolérante (accents, pluriels,
mots dans le désordre, nom anglais Ciqual en repli) → meilleure fiche « crue » ou « cuite ».
Aucune dépendance à un nom exact ; les doublons (« tomato » / « cherry tomatoes ») sont fusionnés.
Un aliment inconnu reste affiché sans fiche, avec « Choisir l'aliment ».

## 7. Modèles de données

```dart
NutrientValue { kind: exact | lessThan | traces | missing, value: double? }
Nutrition     { energyKcal, energyKj, fat, saturatedFat, carbohydrates, sugars,
                fiber, proteins, salt, energySource: direct | convertedFromKj | ciqualJones }
OffProduct    { barcode, name?, brand?, quantity?, imageUrl?, category?, ingredients?,
                allergens[], traces[], labels[], nutriScore? (a–e), nova? (1–4),
                nutrition, nutritionNotProvided }
CiqualFood    { code, name, nameEn?, group?, nutrition, states {raw, cooked, frozen…} }
DetectedFood  { nameFr, nameEn, confidence 0..1, state? }
RecognizedItem{ detection, displayName, emoji, match: CiqualFood?, confirmed }
```

Asset `assets/data/ciqual.json` (généré par `tool/build_ciqual.mjs`) :

```json
{ "source": "Anses. 2025. Table … Ciqual 2025. https://doi.org/10.57745/RDMHWY",
  "licence": "Licence Ouverte / Open Licence 2.0 (Etalab)", "version": "2025_11_03",
  "nutrients": ["kcal","kj","fat","satFat","carbs","sugars","fiber","proteins","salt"],
  "foods": [ { "c": 13000, "n": "Pomme, …, crue", "e": "Apple, …", "g": "fruits",
               "v": [52, 219, "<0.5", null, 13.8, 10.4, 2.4, 0.3, "traces"], "ef": 1 } ] }
```

Requête Open Food Facts :
`GET https://world.openfoodfacts.org/api/v3.4/product/{code}?fields=…&lc=fr`
avec `User-Agent: Caillou/0.1.0 (contact)`.

Requête vision : `POST {baseUrl}/chat/completions` — message système (consigne) + message
utilisateur `[text, image_url(data:image/jpeg;base64,…)]`, `temperature 0`,
`response_format json_object`. Réponse attendue :
`{"foods":[{"name_en":"apple","name_fr":"pomme","state":"raw","confidence":0.97}]}`.

## 8. Structure du projet

```
lib/
  main.dart, app.dart, services.dart, config.dart
  core/        nutrients.dart (valeurs, format FR), text.dart (normalisation)
  data/        food_aliases.dart, history_store.dart
    off/       off_api.dart, off_product.dart, off_repository.dart
    ciqual/    ciqual_food.dart, food_index.dart, food_database.dart
  recognition/ food_recognizer.dart, remote_vision_recognizer.dart,
               food_matcher.dart, recognition_settings.dart
  ui/          home, scanner, product, food, photo, settings, search_results, food_picker_sheet
    widgets/   nutrition_table.dart, common.dart
test/          tests unitaires + widget
tool/          build_ciqual.mjs (+ tests), setup_android.sh
proxy/         Cloudflare Worker facultatif
android/app/src/main/AndroidManifest.xml   (le reste d'android/ est généré)
```

## 9. Écrans

1. **Accueil** : champ « Rechercher un aliment » (résultats instantanés), deux grandes cartes
   « Scanner un produit » / « Prendre une photo », lien « Choisir une photo », « Récemment consultés ».
2. **Scanner** : aperçu caméra plein écran, cadre, lampe, « Saisir le code ».
3. **Fiche produit** : photo, nom, marque, quantité, Nutri-Score / NOVA (si disponibles),
   tableau / 100 g, catégorie, ingrédients, allergènes, traces, labels, attribution.
4. **Fiche aliment** : nom Ciqual, état (cru/cuit…), tableau / 100 g, autres préparations, source.
5. **Photo** : photo, « Aliments détectés » et « À vérifier » (sous 60 % : « Je ne suis pas
   certain de cet aliment. » + « C'est bien ça » / « Corriger »), ajout manuel.
6. **Réglages** : service de vision (préréglages Mistral / Proxy / Local), sources et licences,
   avertissement, effacement des données locales.

## 10. Évolutions prévues (ordre conseillé)

1. Moteur de reconnaissance embarqué (hors ligne) derrière `FoodRecognizer`.
2. Signature APK stable (clé de release en secret GitHub) pour mettre à jour sans désinstaller.
3. Ajout de produits manquants vers Open Food Facts (API d'écriture, compte requis).
4. iOS.
