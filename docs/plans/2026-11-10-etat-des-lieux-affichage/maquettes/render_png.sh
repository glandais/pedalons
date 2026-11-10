#!/usr/bin/env bash
# Rend chaque maquette mobile cible en PNG (Chrome sans fenêtre), dans png/.
# La hauteur vient du `$preview` de l'artboard. `support.js` est fourni par l'artifact :
# un fichier vide suffit ici, les maquettes n'ont que des styles en ligne.
set -euo pipefail
cd "$(dirname "$0")"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
mkdir -p png
: > project/support.js
for f in project/*-mobile-cible.dc.html project/feuille-gps*.dc.html; do
  name="$(basename "$f" .dc.html)"
  h="$(grep -oE '"height":[0-9]+' "$f" | head -1 | cut -d: -f2)"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
    --virtual-time-budget=8000 --window-size="390,${h}" \
    --screenshot="png/${name}.png" "file://$PWD/$f" >/dev/null 2>&1
  echo "${name}.png 390x${h}"
done
rm -f project/support.js
