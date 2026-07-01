#!/usr/bin/env bash
# AttachClip — quick local verification.
# Prints which side of the system is ready and what's missing.
set -e
PASS=0; FAIL=0
ok()   { echo "  ✓ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
echo "AttachClip install verification"
echo "================================"
echo
echo "[1] Helper binary"
BIN="$HOME/.local/bin/attachclip-host"
if [[ -x "$BIN" ]]; then ok "binary present: $BIN"; else fail "binary missing: $BIN"; fi
if file "$BIN" 2>/dev/null | grep -q "arm64\|x86_64"; then ok "binary is native Mach-O"; else fail "binary architecture weird"; fi
echo
echo "[2] Native messaging manifests"
for d in "$HOME/Library/Application Support/Thunderbird/NativeMessagingHosts" \
         "$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"; do
  if [[ -f "$d/com.attachclip.host.json" ]]; then ok "manifest: $d/com.attachclip.host.json"
  else fail "manifest missing: $d/com.attachclip.host.json"; fi
done
echo
echo "[3] Cache dir"
if [[ -d "$HOME/Library/Caches/AttachClip/sessions" ]]; then ok "cache: $HOME/Library/Caches/AttachClip/sessions/"; else fail "cache dir missing"; fi
echo
echo "[4] Thunderbird"
if [[ -d "/Applications/Thunderbird.app" ]]; then
  V=$(/Applications/Thunderbird.app/Contents/MacOS/thunderbird --version 2>/dev/null)
  ok "Thunderbird: $V"
  MAJOR=$(echo "$V" | grep -oE '[0-9]+' | head -1)
  if (( MAJOR >= 128 )); then ok "version ≥ 128 (MV3 supported)"; else fail "version $MAJOR < 128"; fi
else
  fail "Thunderbird not installed at /Applications/Thunderbird.app"
fi
echo
echo "[5] Repo state"
if [[ -d "$HOME/Documents/电脑诊断/thunderbird-attachment-clipboard/.git" ]]; then
  ok "git repo at $HOME/Documents/电脑诊断/thunderbird-attachment-clipboard"
  cd "$HOME/Documents/电脑诊断/thunderbird-attachment-clipboard"
  T=$(git describe --tags --abbrev=0 2>/dev/null || echo "(no tag)")
  ok "current tag: $T"
else
  fail "repo not found"
fi
echo
echo "[6] Extension artefacts"
F="$HOME/Documents/电脑诊断/thunderbird-attachment-clipboard/extension/manifest.json"
if [[ -f "$F" ]]; then ok "manifest present"; else fail "manifest missing"; fi
for s in 48 96 128; do
  if [[ -f "$HOME/Documents/电脑诊断/thunderbird-attachment-clipboard/extension/icons/icon-$s.png" ]]; then
    ok "icon-$s.png present"
  else fail "icon-$s.png missing"; fi
done
echo
echo "Result: $PASS passed, $FAIL failed"
exit $FAIL
