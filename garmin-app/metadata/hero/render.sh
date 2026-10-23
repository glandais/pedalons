#!/usr/bin/env bash
# Renders the Connect IQ Store hero image (1440 x 720) from hero.html, one PNG per language:
# hero-fr-FR.png and hero-en-US.png next to this script. Needs Google Chrome.
set -euo pipefail
cd "$(dirname "$0")"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
for pair in fr:fr-FR en:en-US; do
  lang=${pair%%:*} locale=${pair#*:}
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --force-device-scale-factor=1 --window-size=1440,720 --virtual-time-budget=2000 \
    --screenshot="$PWD/hero-$locale.png" "file://$PWD/hero.html?lang=$lang" 2>/dev/null
  echo "hero-$locale.png"
done
