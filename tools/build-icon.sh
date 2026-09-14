#!/bin/sh
# Convert the source artwork to the standard macOS icon representations.
set -eu
cd "$(dirname "$0")/.."
iconset="build/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512
do
  sips -z "$size" "$size" C128/Resources/AppIcon.png \
    --out "$iconset/icon_${size}x${size}.png" >/dev/null
  doubled=$((size * 2))
  sips -z "$doubled" "$doubled" C128/Resources/AppIcon.png \
    --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o C128/Resources/AppIcon.icns
