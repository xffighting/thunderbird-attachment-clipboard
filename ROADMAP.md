# Roadmap

> AttachClip follows a **macOS-first, alpha-then-beta-then-1.0**
> pathway. Each milestone is gated by the testing matrix in
> [docs/testing-matrix.md](docs/testing-matrix.md) being green.

## v0.1.0-alpha — Initial open-source cut *(this release)*

- ✅ WebExtension (MV3, Thunderbird 128+) with two context menus.
- ✅ macOS Swift helper (`attachclip-host`) implementing the wire
  protocol.
- ✅ 72-hour cache TTL with `clear_cache` verb.
- ⚠️ No icons / no code-sign / no notarization. Add before AMO
  submission.
- ⚠️ No Windows or Linux helper. Docs call this out.

## v0.2.0 — Windows helper (Beta)

- PowerShell + .NET 8 single-file executable shipping as
  `attachclip-host.exe`.
- Installs a per-user manifest under
  `%APPDATA%\Mozilla\NativeMessagingHosts\com.attachclip.host.json`.
- Re-uses the same JSON protocol; just a different transport
  (Windows uses the same Mozilla native-messaging framing).
- Manual test matrix extended with Outlook, Teams, Slack.

## v0.3.0 — Linux helper (Beta)

- Ship a Rust binary that talks to the freedesktop portal via
  `org.freedesktop.portal.FileTransfer`. The portal is the
  blessed way to put a file reference on a Wayland clipboard.
- Document the Flatpak + snap sandbox cases.

## v0.4.0 — Quality + UX

- Browser-action popup with: "Cache used (N files, X MB)", "Clear
  cache now", "Reveal cache in Finder".
- Keyboard shortcut to trigger **Copy All Attachments** on the
  currently displayed message.
- Settings UI for cache TTL (1h, 24h, 72h, 7d, manual).

## v0.5.0 — Apple Silicon notarization

- Acquire Apple Developer ID, code-sign the helper with the
  hardened-runtime flag, submit for notarization.
- `install.sh` downloads the signed zip from GitHub Releases
  rather than building locally (faster + friendlier).

## v1.0.0 — Public, signed, AMO-listed

- All checklist items in CONTRIBUTING.md enforced on CI.
- Submit to addons.thunderbird.net — receive a permanent
  extension ID, set `browser_specific_settings.gecko.id` and
  `update_url`.
- Switch the install script to use AMO-distributed signed XPI;
  manual `about:debugging` load still works for development.
- Comprehensive manual test matrix for **every** supported paste
  target on every supported OS.

## Long term

- **Upstream proposal** — push for a small "copy attachment to
  clipboard" call inside Thunderbird proper, with API like
  `messenger.attachments.copyAsFile(messageId, partName)`.  See
  [docs/upstream-proposal.md](docs/upstream-proposal.md) for the
  early draft.  When that lands, AttachClip becomes a 200-line
  compatibility shim — and then we delete the helper.

## Non-goals

- ❌ Auto-attaching anything to outgoing mail without an explicit
  click. AttachClip **never** writes back to your IMAP server.
- ❌ Cross-device sync. The cache and the pasteboard are inherently
  per-machine.
- ❌ Server-side rendering of any kind.
