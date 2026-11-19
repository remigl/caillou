# Caillou

Application mobile (Flutter, Android) qui affiche les **valeurs nutritionnelles pour 100 g**
d'un aliment, de trois façons :

- **Scanner** un code-barres → fiche produit Open Food Facts ;
- **Rechercher** « brocoli », « pâtes », « pomme » → aliments génériques (table Ciqual, hors ligne) ;
- **Photographier** plusieurs aliments → liste des aliments reconnus, chacun avec ses valeurs / 100 g.

Pas de quantités, pas de compte, pas de score maison. Toute donnée absente est affichée
« Non disponible ».

- Architecture, choix et risques : [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Sources, licences, attributions : [docs/DATA_SOURCES.md](docs/DATA_SOURCES.md)

## Installer l'APK (sans ordinateur)

Chaque push sur `main` construit l'app (GitHub Actions) et publie une pré-version :
**Releases → build-N → caillou-N.apk**, à ouvrir sur le téléphone.

La première fois, lancez une fois **Actions → « Mettre à jour la base Ciqual » → Run workflow** :
la base d'aliments est alors versionnée et les builds suivants vont plus vite.

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

Tests du convertisseur Ciqual : `node --test tool/ciqual_lib.test.mjs`.

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
