# Install on macOS — 3 clicks

> The whole thing takes about 60 seconds and **no terminal, no git clone,
> no Swift toolchain** is needed for end users.

Visual walkthrough: [`docs/img/xpi-install-steps.svg`](img/xpi-install-steps.svg).

## What you'll do

1. **Run one shell command** — downloads the helper binary and registers
   the native-messaging manifest. **One line.**
2. **Download an `.xpi`** from the GitHub release.
3. **Drag it into Thunderbird** — `menu (≡) → Add-ons and Themes → gear
   icon → Install Add-on From File… → pick the .xpi`.

That's it. Restart Thunderbird once and you're done.

---

## Step 1 — install the helper (one line)

Open **Terminal** (`Cmd+Space`, type `terminal`, hit Enter), paste this,
press Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/xffighting/thunderbird-attachment-clipboard/main/scripts/install_for_user.sh | bash
```

What that command does (you don't need to know, but in case you're curious):

| What | Where it lands |
| ---- | -------------- |
| Downloads the prebuilt helper for your Mac's architecture (arm64 or x86_64) | `~/.local/bin/attachclip-host` |
| Drops the native-messaging manifest Thunderbird scans on launch | `~/Library/Application Support/Thunderbird/NativeMessagingHosts/com.attachclip.host.json` |
| Pre-creates the cache directory where attachment files are staged before paste | `~/Library/Caches/AttachClip/sessions/` |

If you want to pin a specific release (recommended for production), set
the env var:

```bash
ATTACHCLIP_VERSION=v0.1.0-alpha.3 curl -fsSL https://raw.githubusercontent.com/xffighting/thunderbird-attachment-clipboard/main/scripts/install_for_user.sh | bash
```

## Step 2 — restart Thunderbird

Fully quit (`Cmd+Q`) and reopen Thunderbird. This lets it pick up the
new native-messaging manifest.

## Step 3 — drag the `.xpi` into Thunderbird

1. Download `attachclip-thunderbird-0.1.0.xpi` from
   [the latest release on GitHub](https://github.com/xffighting/thunderbird-attachment-clipboard/releases/latest).
   Most browsers drop it into `~/Downloads`.
2. In Thunderbird, open the menu (≡) at the top right → **Add-ons and Themes**.
3. Click the **gear icon** ⚙ at the top right of the Add-ons Manager.
4. Choose **Install Add-on From File…**.
5. Navigate to `~/Downloads`, pick the `.xpi`, click **Open**.
6. Click **Allow** on the permission prompt. AttachClip only asks for
   `messagesRead`, `nativeMessaging`, `contextMenus`, `notifications`,
   and `menus` — **never** `messagesModify`, `compose`, or `sending`.

The add-on is now installed and persists across Thunderbird restarts.
(Temporary loaders via `about:debugging` are removed when TB closes —
not what you want.)

## Step 4 — try it

1. Open any email that has at least one attachment.
2. Right-click the attachment → **Copy Attachment as File**.
3. Switch to Finder (or WeChat, Lark, DingTalk, Slack, a new Thunderbird
   compose window) → press **Cmd+V**.
4. The real file appears with its original filename and extension.

For multi-attachment emails, right-click the message itself and pick
**Copy All Attachments as Files**.

---

## Common gotchas

| Symptom | Fix |
| ------- | --- |
| Terminal says `permission denied` | `chmod +x ~/local/bin` doesn't help; instead the helper binary should already be 0755 — verify with `ls -l ~/.local/bin/attachclip-host`. |
| Thunderbird's "Install Add-on From File…" is greyed out | TB is signed and you must explicitly enable unsigned add-ons: `about:config` → `xpinstall.signatures.required` = `false`. Only relevant for Thunderbird 115 ESR; TB 128+ ships with a more permissive default for temporary + signed add-ons. |
| Right-click menu items don't show | Restart Thunderbird once more (Cmd+Q then reopen). The native messaging registry is only re-read on launch. |
| Cmd+V pastes text instead of a file | The target app doesn't accept file drops from clipboard. Check `docs/testing-matrix.md` for known-good targets. |
| `attachclip-host not found` in TB console | Helper path in the manifest is wrong. Re-run Step 1; it re-creates the manifest with the absolute path of the installed binary. |

## Uninstall

End users:

```bash
curl -fsSL https://raw.githubusercontent.com/xffighting/thunderbird-attachment-clipboard/main/scripts/uninstall_for_user.sh | bash
```

Then in Thunderbird: menu (≡) → Add-ons and Themes → find "AttachClip
for Thunderbird" → **Remove**. Restart Thunderbird.

## Developer install (alternative)

If you want to hack on the extension itself or rebuild the helper,
use the source install path: `git clone … && cd native-host/macos &&
./install.sh`. That's documented in
[`native-host/macos/install.sh`](../native-host/macos/install.sh) and is
only needed for contributors. End users should use the one-line curl
installer above.