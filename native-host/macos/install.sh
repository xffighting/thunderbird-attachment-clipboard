#!/usr/bin/env bash
#
# AttachClip for Thunderbird — install.sh
# ----------------------------------------
# 1. Compile the Swift helper via `swift build -c release` (arch auto-detected).
# 2. Copy the resulting binary to $HOME/.local/bin/attachclip-host.
# 3. Render host-manifest.template.json with the resolved binary path.
# 4. Drop the native-messaging manifest into the locations Thunderbird
#    actually scans on macOS:
#       $HOME/Library/Application Support/Thunderbird/NativeMessagingHosts/
#    plus the Firefox-compatible location as a courtesy:
#       $HOME/Library/Application Support/Mozilla/NativeMessagingHosts/
# 5. Print a post-install checklist with the exact about:debugging path
#    Thunderbird 128+ uses.
#
# Re-running is safe: it overwrites the manifest and replaces the binary.
#

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_NAME="com.attachclip.host"
BUILD_DIR="$HERE/.build"

# Detect host arch so we produce a binary that runs natively (no Rosetta).
HOST_ARCH="$(uname -m)"
case "$HOST_ARCH" in
  arm64|aarch64) TARGET_TRIPLE="arm64-apple-macosx12.0" ;;
  x86_64)        TARGET_TRIPLE="x86_64-apple-macosx12.0" ;;
  *)
    echo "ERROR: unsupported host architecture '$HOST_ARCH'." >&2
    exit 1
    ;;
esac

# Destinations (user-scope only — system-scope would need root + sudo prompts).
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

# All locations Thunderbird (and Firefox) look at on macOS.
# Thunderbird on macOS scans BOTH:
#   * $HOME/Library/Application Support/Thunderbird/NativeMessagingHosts/
#   * /Library/Application Support/Thunderbird/NativeMessagingHosts/      (system, root)
# but it does NOT scan $HOME/Library/Application Support/Mozilla/.
# We still drop a copy into the Mozilla/ folder so the same helper works
# in Firefox if anyone copies the extension across.
MANIFEST_DIRS=(
  "$HOME/Library/Application Support/Thunderbird/NativeMessagingHosts"
  "$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
)

echo "==> Detected host arch : $HOST_ARCH (target triple: $TARGET_TRIPLE)"
echo "==> Building Swift helper (release)…"
( cd "$HERE" && swift build -c release --triple "$TARGET_TRIPLE" )

BUILT_BIN="$BUILD_DIR/release/attachclip-host"
if [[ ! -x "$BUILT_BIN" ]]; then
  echo "ERROR: build succeeded but $BUILT_BIN is missing."
  exit 1
fi

INSTALLED_BIN="$BIN_DIR/attachclip-host"
echo "==> Installing binary to $INSTALLED_BIN"
cp -f "$BUILT_BIN" "$INSTALLED_BIN"
chmod 0755 "$INSTALLED_BIN"

# Render the manifest once into a temp file, then copy to every location.
TMP_MANIFEST="$(mktemp -t attachclip-manifest.XXXXXX)"
trap 'rm -f "$TMP_MANIFEST"' EXIT

ALLOWED_ORIGINS='"allowed_extensions": ["attachclip-thunderbird@example.com"]'

python3 - "$INSTALLED_BIN" "$HERE/host-manifest.template.json" "$TMP_MANIFEST" <<PY
import json, sys
binary, tpl_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(tpl_path, "r", encoding="utf-8") as f:
    data = f.read()
data = data.replace("__BINARY_PATH__", binary)
data = data.replace("__ALLOWED_ORIGINS__",
    '"allowed_extensions": ["attachclip-thunderbird@example.com"]')
parsed = json.loads(data)
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(parsed, f, indent=2, sort_keys=True)
    f.write("\n")
PY

for DIR in "${MANIFEST_DIRS[@]}"; do
  mkdir -p "$DIR"
  cp -f "$TMP_MANIFEST" "$DIR/${HOST_NAME}.json"
  echo "==> Wrote manifest : $DIR/${HOST_NAME}.json"
done

# Pre-create the cache directory so the helper has somewhere to write.
mkdir -p "$HOME/Library/Caches/AttachClip/sessions"
echo "==> Cache dir       : $HOME/Library/Caches/AttachClip/sessions/"

cat <<EOF

================================================================
  AttachClip helper installed.
================================================================

  Binary   : $INSTALLED_BIN
  Arch     : $HOST_ARCH
  Manifest : ${MANIFEST_DIRS[0]}/${HOST_NAME}.json
  Cache    : $HOME/Library/Caches/AttachClip/

Next steps:
  1. Restart Thunderbird 128+ so it re-reads native messaging manifests.
  2. In Thunderbird, open:
       about:debugging#/runtime/this-mv3
     then click "Load Temporary Add-on…" and pick:
       $HERE/../../extension/manifest.json
  3. Open any email with an attachment, right-click it, choose
     "Copy Attachment as File".  Finder should paste a real file on Cmd+V.

  Removing:  $HERE/uninstall.sh
EOF