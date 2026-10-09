#!/usr/bin/env bash
# Copies the Play cards rendered by Koubou (screenshots/koubou/play.yaml) into the fastlane
# listing, android/fastlane/metadata/android/<locale>/images/phoneScreenshots/, replacing what was
# there — fastlane `supply` uploads that folder as is, in file-name order — and the feature graphic
# (screenshots/koubou/feature.yaml) into images/featureGraphic.png.
#
#   (cd screenshots/koubou && kou generate play.yaml && kou generate feature.yaml) && ./screenshots/assemble-play.sh

set -euo pipefail
cd "$(dirname "$0")/.."

SRC="screenshots/koubou/out/play"
DST="android/fastlane/metadata/android"
[ -d "$SRC" ] || { echo "✖ no render under $SRC — run: cd screenshots/koubou && kou generate play.yaml" >&2; exit 1; }

for dir in "$SRC"/*/; do
  locale=$(basename "$dir")
  out="$DST/$locale/images/phoneScreenshots"
  [ -d "$DST/$locale" ] || { echo "✖ $DST/$locale does not exist: a Play locale is added there first" >&2; exit 1; }
  rm -rf "$out"
  mkdir -p "$out"
  n=0
  while IFS= read -r png; do
    size=$(sips -g pixelWidth -g pixelHeight "$png" | awk '/pixel/ {printf "%s%s", sep, $2; sep="x"}')
    [ "$size" = "1080x1920" ] || { echo "✖ $png is $size, 1080x1920 expected" >&2; exit 1; }
    cp "$png" "$out/$(basename "$png")"
    n=$((n + 1))
  done < <(find "$dir" -name '[0-9][0-9]-*.png' | sort)
  [ "$n" -ge 2 ] && [ "$n" -le 8 ] || { echo "✖ $locale: $n cards, Play wants 2 to 8" >&2; exit 1; }
  echo "✔ $locale: $n cards -> $out"
  feature=$(find "screenshots/koubou/out/feature/$locale" -name featureGraphic.png 2>/dev/null | head -n1)
  [ -n "$feature" ] || { echo "✖ $locale: no feature graphic — run: kou generate feature.yaml" >&2; exit 1; }
  cp "$feature" "$DST/$locale/images/featureGraphic.png"
  echo "✔ $locale: feature graphic"
done
