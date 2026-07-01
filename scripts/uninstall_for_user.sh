#!/usr/bin/env bash
#
# AttachClip for Thunderbird — one-line uninstaller
# --------------------------------------------------
# Mirrors install_for_user.sh in reverse:
#   * Deletes the helper binary from ~/.local/bin/attachclip-host
#   * Removes native-messaging manifests from every location they were written
#   * Removes the cache directory entirely (paste clipboard files only)
#   * Leaves Thunderbird profile data alone
#
# Pipe-friendly:
#   curl -fsSL https://raw.githubusercontent.com/xffighting/thunderbird-attachment-clipboard/main/scripts/uninstall_for_user.sh | bash

set -euo pipefail

HOST_NAME="com.attachclip.host"
BIN="$HOME/.local/bin/attachclip-host"

echo "==> Removing helper binary"
if [[ -e "$BIN" ]]; then
  rm -f "$BIN"
  echo "    deleted: $BIN"
else
  echo "    not present: $BIN"
fi

echo "==> Removing native-messaging manifests"
for DIR in \
  "$HOME/Library/Application Support/Thunderbird/NativeMessagingHosts" \
  "$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"; do
  MANIFEST="$DIR/${HOST_NAME}.json"
  if [[ -e "$MANIFEST" ]]; then
    rm -f "$MANIFEST"
    echo "    deleted: $MANIFEST"
  fi
done

echo "==> Removing cache directory"
CACHE_DIR="$HOME/Library/Caches/AttachClip"
if [[ -d "$CACHE_DIR" ]]; then
  rm -rf "$CACHE_DIR"
  echo "    deleted: $CACHE_DIR"
else
  echo "    not present: $CACHE_DIR"
fi

cat <<'EOF'

================================================================
  AttachClip helper uninstalled.
================================================================

  To finish removing the add-on itself:
    Thunderbird -> menu (≡) -> Add-ons and Themes
    -> find "AttachClip for Thunderbird"
    -> click "Remove".

  Restart Thunderbird afterwards so it stops scanning the (now-gone)
  native-messaging manifest.
================================================================
EOF