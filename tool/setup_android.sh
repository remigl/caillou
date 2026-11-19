#!/usr/bin/env bash
# Génère le projet Android Flutter manquant (sans écraser lib/, pubspec.yaml ni le manifeste versionné),
# puis applique les réglages nécessaires aux plugins.
#   bash tool/setup_android.sh
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create --platforms=android --org dev.remigl --project-name caillou . >/dev/null

GRADLE=android/app/build.gradle.kts
if [ -f "$GRADLE" ]; then
  # mobile_scanner / image_picker récents : minSdk 24 suffit et reste compatible avec ~99 % des téléphones.
  sed -i.bak -E 's/minSdk = flutter\.minSdkVersion/minSdk = maxOf(24, flutter.minSdkVersion)/' "$GRADLE"
  rm -f "$GRADLE.bak"
elif [ -f android/app/build.gradle ]; then
  sed -i.bak -E 's/minSdkVersion flutter\.minSdkVersion/minSdkVersion Math.max(24, flutter.minSdkVersion)/' android/app/build.gradle
  rm -f android/app/build.gradle.bak
fi

echo "Projet Android prêt (android/)."
