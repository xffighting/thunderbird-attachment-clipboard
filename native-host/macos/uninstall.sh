#!/usr/bin/env bash
#
# AttachClip for Thunderbird — uninstall.sh
# ------------------------------------------
# * Remove the installed binary.
# * Remove the user AND system native messaging manifests (if present).
# * Optionally wipe the cache (default: yes).
#
# Safe to re-run.  We never touch the Thunderbird extension itself; remove
# it via about:debugging -> Remove or by deleting the XPI from your
# profile.
#

set -euo pipefail

HOST_NAME="com.attachclip.host"

USER_BIN="$HOME/.local/bin/attachclip-host"
ROOT_BIN="/usr/local/bin/attachclip-host"
USER_MANIFEST="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts/${HOST_NAME}.json"
SYS_MANIFEST="/Library/Application Support/Mozilla/NativeMessagingHosts/${HOST_NAME}.json"

echo "==> Removing binary"
for b in "$USER_BIN" "$ROOT_BIN"; do
  if [[ -e "$b" ]]; then
    if [[ -w "$(dirname "$b")" ]]; then
      rm -f "$b"
    else
      sudo rm -f "$b"
    fi
    echo "    removed $b"
  fi
done

echo "==> Removing native messaging manifest"
for m in "$USER_MANIFEST" "$SYS_MANIFEST"; do
  if [[ -e "$m" ]]; then
    if [[ -w "$(dirname "$m")" ]]; then
      rm -f "$m"
    else
      sudo rm -f "$m"
    fi
    echo "    removed $m"
  fi
done

echo "==> Clearing cache directory"
CACHE_DIR="$HOME/Library/Caches/AttachClip"
if [[ -d "$CACHE_DIR" ]]; then
  rm -rf "$CACHE_DIR"
  echo "    removed $CACHE_DIR"
else
  echo "    no cache dir found at $CACHE_DIR"
fi

cat <<EOF

================================================================
  AttachClip helper uninstalled.
================================================================

Next steps:
  1. Restart Thunderbird so it forgets the helper.
  2. Optionally remove the extension itself via:
       about:debugging#/runtime/this-firefox  →  AttachClip → Remove
EOF
