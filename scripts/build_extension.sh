#!/usr/bin/env bash
# scripts/build_extension.sh — pack the WebExtension into a non-signed .xpi
# Usage: ./scripts/build_extension.sh [output_dir]
#
# Output: <output_dir>/attachclip-thunderbird-<git_describe>.xpi
# Default output_dir: ./scripts/dist

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
OUT="${1:-$ROOT/scripts/dist}"

mkdir -p "$OUT"
cd "$ROOT/extension"

VERSION="$(git -C "$ROOT" describe --tags --always 2>/dev/null || echo dev)"
OUT_FILE="$OUT/attachclip-thunderbird-${VERSION}.xpi"

echo "==> Packing extension ($VERSION)"
zip -qr "$OUT_FILE" . -x '*.DS_Store' 'src/config.local.js'
shasum -a 256 "$OUT_FILE" > "$OUT_FILE.sha256"

echo "Wrote: $OUT_FILE"
cat "$OUT_FILE.sha256"
