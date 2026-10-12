#!/usr/bin/env bash
# Rend les PNG de l'icône et de l'écran de démarrage depuis les HTML de ce dossier (Chrome sans interface),
# puis régénère les fichiers Android et iOS.
#   ./design/app-icon/render.sh
set -euo pipefail
cd "$(dirname "$0")"
chrome="${CHROME:-/c/Program Files/Google/Chrome/Application/chrome.exe}"
out=../../app/assets/launcher
mkdir -p "$out"
shot() { # $1 html, $2 png, $3 largeur, $4 hauteur
  "$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --default-background-color=00000000 --window-size="$3,$4" \
    --screenshot="$(cygpath -w "$PWD/$out/$2" 2>/dev/null || echo "$PWD/$out/$2")" "file:///$(cygpath -m "$PWD/$1" 2>/dev/null || echo "$PWD/$1")" 2>/dev/null
}
shot icon.html icon.png 1024 1024
shot foreground.html foreground.png 1024 1024
shot splash.html splash.png 1152 1152
shot branding.html branding.png 800 240
cd ../../app
dart run flutter_launcher_icons
dart run flutter_native_splash:create
