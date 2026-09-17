#!/bin/sh
# Optional third-party reference vectors; no emulator implementation is fetched.
# Fuse/libretro test data: https://github.com/libretro/fuse-libretro (GPL-3.0).
set -eu
cd "$(dirname "$0")/.."
runner=${1:-./build/CPUZ80Tests}
revision=958105a90ad2b5825ad002ba563cc3f9f879d763
reference_dir=build/z80-reference
mkdir -p "$reference_dir"
for name in tests.in tests.expected; do
  curl --fail --location --silent --show-error \
    "https://raw.githubusercontent.com/libretro/fuse-libretro/$revision/fuse/z80/tests/$name" \
    -o "$reference_dir/$name"
done
exec "$runner" "$reference_dir"
