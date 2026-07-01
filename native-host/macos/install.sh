#!/usr/bin/env bash
#
# AttachClip for Thunderbird — install.sh
# ----------------------------------------
# 1. Compile the Swift helper via `swift build -c release`.
# 2. Copy the resulting binary to /usr/local/bin (or $HOME/.local/bin if
#    we don't have root) and chmod 0755.
# 3. Render host-manifest.template.json with the resolved binary path
#    and copy it to the Thunderbird-discoverable location:
#       ~/Library/Application Support/Mozilla/NativeMessagingHosts/
#       com.attachclip.host.json
#    (when running as the user)
# 4. Print a post-install checklist.
#
# Re-running is safe: it overwrites the manifest and replaces the binary.
#

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_NAME="com.attachclip.host"
DISPLAY_NAME="AttachClip for Thunderbird"
BUILD_DIR="$HERE/.build"
TARGET_TRIPLE="x86_64-apple-macosx12.0"

# Destinations
if [[ $EUID -eq 0 ]]; then
  BIN_DIR="/usr/local/bin"
  MANIFEST_DIR="/Library/Application Support/Mozilla/NativeMessagingHosts"
  SUDO=""
else
  BIN_DIR="$HOME/.local/bin"
  MANIFEST_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
  SUDO=""
fi

mkdir -p "$BIN_DIR" "$MANIFEST_DIR"

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

# Render the manifest from the template.  Whichever manifest path Thunderbird
# resolves first wins, but Firefox/Thunderbird look in:
#   * $HOME/Library/Application Support/Mozilla/NativeMessagingHosts/
#   * /Library/Application Support/Mozilla/NativeMessagingHosts/
# We write only the user-scope manifest; root callers also get the system one.
RENDERED="$MANIFEST_DIR/${HOST_NAME}.json"
echo "==> Writing native messaging manifest to $RENDERED"

ALLOWED_ORIGINS='"allowed_extensions": ["attachclip-thunderbird@example.com"]'

python3 - "$INSTALLED_BIN" "$HERE/host-manifest.template.json" "$RENDERED" <<'PY'
import json, sys
binary, tpl_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(tpl_path, "r", encoding="utf-8") as f:
    data = f.read()
# Substitute placeholders.  We avoid sed because the template contains slashes
# and escaped quotes inside JSON.
data = data.replace("__BINARY_PATH__", binary)
data = data.replace("__ALLOWED_ORIGINS__",
    '"allowed_extensions": ["attachclip-thunderbird@example.com"]')
# Validate the result parses as JSON
parsed = json.loads(data)
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(parsed, f, indent=2, sort_keys=True)
    f.write("\n")
PY

if [[ $EUID -eq 0 ]]; then
  # Also drop a system-wide manifest so multiple profiles / users benefit.
  SYS_DIR="/Library/Application Support/Mozilla/NativeMessagingHosts"
  mkdir -p "$SYS_DIR"
  cp -f "$RENDERED" "$SYS_DIR/${HOST_NAME}.json"
  echo "==> Also wrote system manifest at $SYS_DIR/${HOST_NAME}.json"
fi

cat <<EOF

================================================================
  AttachClip helper installed.
================================================================

  Binary : $INSTALLED_BIN
  Manifest: $RENDERED
  Cache   : $HOME/Library/Caches/AttachClip/

Next steps:
  1. Restart Thunderbird so it re-reads native messaging manifests.
  2. Open this URL in Thunderbird:
       about:debugging#/runtime/this-firefox
     then click "Load Temporary Add-on…" and pick:
       $HERE/../../extension/manifest.json
  3. Open any email with an attachment, right-click, choose
     "Copy Attachment as File".  Finder should paste a real file on Cmd+V.

  Removing:  ./uninstall.sh
EOF
