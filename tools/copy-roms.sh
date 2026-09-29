#!/bin/sh
set -eu

destination=$1
for rom in roms/*.rom; do
  [ -f "$rom" ] || continue
  mkdir -p "$destination"
  cp "$rom" "$destination/"
done
