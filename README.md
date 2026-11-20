# Caillou

Application mobile (Flutter, Android) qui affiche les **valeurs nutritionnelles pour 100 g**
d'un aliment, de trois façons :

- **Scanner** un code-barres → fiche produit Open Food Facts ;
- **Rechercher** « brocoli », « pâtes », « pomme » → aliments génériques (table Ciqual, hors ligne) ;
- **Photographier** plusieurs aliments → liste des aliments reconnus, chacun avec ses valeurs / 100 g.

Au-delà des calories : additifs (nom et rôle), végétalien / végétarien / huile de palme, repères
faible-modéré-élevé, score environnemental et CO₂ (Agribalyse), origine, prix relevés (Open Prices),
vitamines et minéraux, et pour chaque produit l'aliment générique Ciqual comparable avec sa composition
détaillée.

Également : alerte si le produit scanné fait l'objet d'un rappel officiel (RappelConso, FDA), % des apports
de référence UE et des VNR, repère « 10 g de glucides », acides aminés (USDA), et **composition de repas** avec
quantités, totaux et suggestions pour le compléter.

Pas de compte, pas de score maison, pas d'estimation de quantités sur les photos. Toute donnée absente est affichée
« Non disponible ».

- Architecture, choix et risques : [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Sources, licences, attributions : [docs/DATA_SOURCES.md](docs/DATA_SOURCES.md)

## Installer l'APK (sans ordinateur)

Dernière version : **Releases → Caillou vX.Y.Z → caillou-vX.Y.Z.apk**, à ouvrir sur le téléphone
(Android 7.0 ou plus, autoriser l'installation depuis cette source).

- Publier une version : mettre à jour `version:` dans `pubspec.yaml`, puis pousser sur la branche
  `release` → build et release GitHub `vX.Y.Z` automatiques.
- Chaque push sur `main` publie aussi une pré-version de test `build-N`.
- En cas d'échec du build, le journal est poussé dans la branche `ci-log` (lisible sans connexion).
- La base Ciqual est versionnée (`assets/data/ciqual.json`) ; pour la régénérer :
  **Actions → « Mettre à jour la base Ciqual » → Run workflow**.

Les APK sont signés avec une clé de débogage générée à chaque build : pour passer d'une version à
une autre, désinstallez d'abord l'ancienne (une clé de signature stable est la prochaine étape).

## Développer en local

Prérequis : Flutter (stable), Node ≥ 20, un téléphone Android ou un émulateur.

```bash
git clone https://github.com/remigl/caillou && cd caillou
node tool/build_ciqual.mjs        # télécharge et convertit Ciqual 2025 -> assets/data/ciqual.json
bash tool/setup_android.sh        # génère le projet Android (flutter create) sans écraser le code
flutter pub get
flutter test
flutter run                       # ou : flutter build apk --release
```

Tests du convertisseur Ciqual : `node --test tool/ciqual_lib.test.mjs tool/additives_lib.test.mjs`.

## Reconnaissance photo

Réglages → choisir un service :

| Préréglage | Adresse | Modèle | Clé |
|---|---|---|---|
| Mistral | `https://api.mistral.ai/v1` | `mistral-small-latest` | clé personnelle (console.mistral.ai) |
| Proxy Caillou | `https://<worker>.workers.dev/v1` | `auto` | jeton facultatif — voir [proxy/](proxy/README.md) |
| Local (Ollama) | `https://<votre-pc>/v1` | `qwen2.5vl:7b` | aucune |

Toute API compatible « Chat Completions » acceptant des images fonctionne. La clé reste sur le
téléphone ; pour distribuer l'app à d'autres, utilisez le proxy (la clé reste côté serveur).

Seuil de confiance : 60 % (`lib/config.dart`). En dessous : « Je ne suis pas certain de cet
aliment » et possibilité de confirmer ou corriger.

## Structure

```
lib/core         valeurs nutritionnelles, normalisation du texte
lib/data         Open Food Facts (API + cache), Ciqual (index de recherche), alias, historique
lib/recognition  reconnaissance photo et correspondance vers Ciqual
lib/ui           écrans
tool/            génération de la base Ciqual, préparation Android
proxy/           proxy facultatif (Cloudflare Worker)
```

## Licences des données

Open Food Facts : ODbL (base), DbCL (contenus), CC BY-SA (photos).
Ciqual 2025 : Anses, Licence Ouverte 2.0 — https://doi.org/10.57745/RDMHWY.
Projet indépendant, sans lien avec Yuka ni aucune autre application de scan.
