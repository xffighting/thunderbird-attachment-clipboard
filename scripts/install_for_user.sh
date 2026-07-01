#!/usr/bin/env bash
#
# AttachClip for Thunderbird — one-line installer for end users
# --------------------------------------------------------------
# This is the path users SHOULD follow. No git clone. No Swift toolchain
# required. It downloads a prebuilt helper binary from the GitHub release
# tagged in $ATTACHCLIP_VERSION (default: latest), drops it into
# $HOME/.local/bin/, renders the native-messaging manifest, and registers
# it in every location Thunderbird actually scans on macOS.
#
# Safe to pipe from curl:
#
#   curl -fsSL https://raw.githubusercontent.com/xffighting/thunderbird-attachment-clipboard/main/scripts/install_for_user.sh | bash
#
# Override the release tag with ATTACHCLIP_VERSION=v0.1.0-alpha.3 etc.

set -euo pipefail

HOST_NAME="com.attachclip.host"
REPO="${ATTACHCLIP_REPO:-xffighting/thunderbird-attachment-clipboard}"
VERSION="${ATTACHCLIP_VERSION:-v0.1.0-alpha.3}"

# 1) Resolve the helper binary for this Mac's architecture.
HOST_ARCH="$(uname -m)"
case "$HOST_ARCH" in
  arm64|aarch64) HELPER_ASSET="attachclip-host-arm64" ;;
  x86_64)        HELPER_ASSET="attachclip-host-x86_64" ;;
  *)
    echo "ERROR: unsupported architecture '$HOST_ARCH'. Build the Swift helper yourself with ./install.sh." >&2
    exit 1
    ;;
esac

BASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"
TMP_DIR="$(mktemp -d -t attachclip-installer.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "==> AttachClip user installer"
echo "    Repo    : $REPO"
echo "    Version : $VERSION"
echo "    Arch    : $HOST_ARCH ($HELPER_ASSET)"
echo

echo "==> Downloading helper binary..."
# GitHub release-assets endpoint returns 404 unless a User-Agent header is
# sent. Provide a stable UA so the install is reproducible.
curl -fSL --retry 3 \
  -A "AttachClipInstaller/0.1 (+https://github.com/${REPO})" \
  -o "$TMP_DIR/helper" \
  "$BASE_URL/$HELPER_ASSET"
chmod 0755 "$TMP_DIR/helper"

echo "==> Verifying signature (sha256)..."
EXPECTED="$(curl -fsSL \
  -A "AttachClipInstaller/0.1 (+https://github.com/${REPO})" \
  "$BASE_URL/SHA256SUMS" | awk -v a="$HELPER_ASSET" '$2==a {print $1}')"
ACTUAL="$(shasum -a 256 "$TMP_DIR/helper" | awk '{print $1}')"
if [[ -z "$EXPECTED" ]]; then
  echo "WARN: no SHA256SUMS entry for $HELPER_ASSET in $VERSION; skipping verification."
elif [[ "$EXPECTED" != "$ACTUAL" ]]; then
  echo "ERROR: checksum mismatch." >&2
  echo "  expected: $EXPECTED" >&2
  echo "  actual  : $ACTUAL" >&2
  exit 1
else
  echo "    sha256 OK ($ACTUAL)"
fi

# 2) Install binary to ~/.local/bin.
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
INSTALLED_BIN="$BIN_DIR/attachclip-host"
mv -f "$TMP_DIR/helper" "$INSTALLED_BIN"
echo "==> Installed binary: $INSTALLED_BIN"

# 3) Write the native-messaging manifest into every location TB scans.
MANIFEST_DIRS=(
  "$HOME/Library/Application Support/Thunderbird/NativeMessagingHosts"
  "$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
)

for DIR in "${MANIFEST_DIRS[@]}"; do
  mkdir -p "$DIR"
  cat > "$DIR/${HOST_NAME}.json" <<JSON
{
  "name": "${HOST_NAME}",
  "description": "AttachClip native helper (clipboard writer + cache store)",
  "path": "${INSTALLED_BIN}",
  "type": "stdio",
  "allowed_extensions": ["attachclip-thunderbird@example.com"]
}
JSON
  echo "==> Wrote manifest : $DIR/${HOST_NAME}.json"
done

# 4) Pre-create the cache directory.
mkdir -p "$HOME/Library/Caches/AttachClip/sessions"
echo "==> Cache dir       : $HOME/Library/Caches/AttachClip/sessions/"

cat <<EOF

================================================================
  AttachClip helper installed. Just two more clicks in Thunderbird:
================================================================

  Step 1. Restart Thunderbird 128+ so it picks up the new manifest.

  Step 2. Download the add-on (.xpi) from:
            https://github.com/${REPO}/releases/download/${VERSION}/attachclip-thunderbird-0.1.0.xpi

  Step 3. In Thunderbird, open the menu (≡) -> "Add-ons and Themes".
          Click the gear icon -> "Install Add-on From File...".
          Pick the .xpi you just downloaded.
          Confirm the permission prompt.

  Step 4. Open any email with an attachment, right-click it, choose
          "Copy Attachment as File".  Switch to Finder, hit Cmd+V —
          a real file lands on the desktop.

  Uninstall:
    curl -fsSL https://raw.githubusercontent.com/${REPO}/main/scripts/uninstall_for_user.sh | bash
================================================================
EOF