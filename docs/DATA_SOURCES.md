# Sources de données, licences et obligations

## Open Food Facts — produits avec code-barres

- **Quoi** : base collaborative mondiale de produits alimentaires (nom, marque, ingrédients,
  allergènes, Nutri-Score, NOVA, labels, valeurs nutritionnelles normalisées pour 100 g).
- **Accès** : API publique sans clé, `GET https://world.openfoodfacts.org/api/v3.4/product/{code}`.
  L'API v3 est la version recommandée ; la sous-version 3.4 est figée car la 3.5 modifie la
  structure des nutriments (en développement).
- **Conditions d'utilisation de l'API** :
  - User-Agent personnalisé obligatoire : `NomApp/Version (contact)` → `AppConfig.userAgent`
    (mettre une adresse e-mail avant diffusion publique) ;
  - limites : 15 lectures produit / min / IP, 10 recherches / min / IP, pas de recherche à la
    frappe → l'app n'utilise pas la recherche Open Food Facts et met les produits en cache ;
  - au-delà de quelques centaines de produits, utiliser les exports (CSV/JSONL), pas l'API.
- **Licences** :
  - base de données : **Open Database License (ODbL)** ;
  - contenus individuels : **Database Contents License (DbCL)** ;
  - photos : **Creative Commons BY-SA 3.0** (peuvent contenir des éléments graphiques protégés).
- **Obligations** : attribuer Open Food Facts et ses contributeurs (fait sur chaque fiche et
  dans les réglages) ; toute base dérivée **publiée** doit rester sous ODbL (le cache local de
  l'app n'est pas publié) ; ne combiner qu'avec des sources compatibles avec cette redistribution.
- **Limites** : données saisies par des bénévoles, sans garantie d'exactitude ni d'exhaustivité ;
  produits absents ; Nutri-Score/NOVA parfois non calculés ; valeurs parfois par portion seulement.
- Docs : https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/

## Table Ciqual 2025 (Anses) — aliments génériques

- **Quoi** : table française de référence sur la composition nutritionnelle de 3 484 aliments
  (bruts et transformés), valeurs moyennes pour 100 g de partie comestible ; distingue cru, cuit,
  surgelé, en conserve, etc.
- **Version utilisée** : Ciqual 2025, fichiers XML du 3 novembre 2025, publiés le 19 novembre 2025.
  DOI : https://doi.org/10.57745/RDMHWY (Recherche Data Gouv), miroir Zenodo
  https://zenodo.org/records/17550133 utilisé par le script (sommes MD5 vérifiées).
- **Licence** : **Licence Ouverte / Open Licence 2.0 (Etalab)** — réutilisation libre, y compris
  commerciale, modification autorisée.
- **Obligation** : mentionner la paternité (source et date de dernière mise à jour). Mention
  utilisée : « Anses. 2025. Table de composition nutritionnelle des aliments Ciqual 2025 »,
  affichée sur chaque fiche aliment et dans les réglages, et stockée dans l'asset JSON.
- **Limites** :
  - certaines teneurs manquent (« - »), sont des « traces » ou des « < x » : conservées et affichées
    telles quelles ;
  - l'énergie « règlement UE » peut manquer : l'app utilise alors la valeur Anses
    « N × facteur de Jones, avec fibres » et l'indique ;
  - moyennes nationales : un produit réel peut différer ; pas de marques.
- **Champs extraits** (par nom de constituant, pas par numéro, pour résister à une renumérotation) :
  énergie kJ/kcal (UE 1169/2011, repli Jones), lipides, AG saturés, glucides, sucres, fibres
  alimentaires, protéines (N × facteur de Jones, repli N × 6,25), sel.

## Reconnaissance d'image

- Pas une source de données nutritionnelles : elle ne fait que **nommer** les aliments ;
  toutes les valeurs viennent ensuite de Ciqual.
- Fournisseur au choix de l'utilisateur (Mistral, modèle local, proxy). Lire ses conditions :
  usage des images (entraînement ou non selon l'offre), localisation des serveurs, coûts.

## Indépendance vis-à-vis de Yuka

- Aucune donnée Yuka (ni base, ni note, ni API), aucune capture ni élément d'interface, aucun
  nom ou slogan. Pas de note globale ni de code couleur « bon / mauvais » : Caillou affiche des
  valeurs sourcées, pas de jugement.
- Nutri-Score et NOVA sont des systèmes publics (Santé publique France ; Université de São Paulo),
  repris tels que calculés par Open Food Facts et affichés en texte, sans leurs logos.
