#!/bin/sh
# Format owned Objective-C sources, or verify that they already match.
set -eu
cd "$(dirname "$0")/.."
formatter=${CLANG_FORMAT:-clang-format}
case ${1:-} in
  --check)
    set -- --dry-run --Werror
    ;;
  '')
    set -- -i
    ;;
  *)
    echo "Usage: $0 [--check]" >&2
    exit 2
    ;;
esac
exec "$formatter" --style=file "$@" \
  C128/*.h C128/*.m C128/CPU/*.h C128/CPU/*.m \
  C128/Core/*.h C128/Core/*.m C128/UI/*.h C128/UI/*.m Tests/*.m
