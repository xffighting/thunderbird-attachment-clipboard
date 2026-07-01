# Changelog

All notable changes to **AttachClip for Thunderbird** are documented in
this file. The format follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

Pre-release tags use the form `vMAJOR.MINOR.PATCH-pre.N` and **are
not** considered stable.

---

## [Unreleased]

### Added
- (placeholder — populate on next merge)

## [0.1.0-alpha.2] — 2026-07-01

> Local-installable alpha. macOS only. Verified end-to-end with
> `scripts/smoke_test.py` against the freshly built arm64 helper.

### Added
- Programmatic 48/96/128 icons (`extension/icons/`), wired into
  `manifest.json`.
- `scripts/build_icons.py` — reproducible PIL-only icon generator.
- `scripts/build_xpi.py` — reproducible XPI packer with SHA-256 sidecar.
- `dist/attachclip-thunderbird-0.1.0.xpi` (25 KB, SHA-256 verified).

### Fixed
- `install.sh` now detects host arch (arm64 vs x86_64) instead of
  hard-coding x86_64. Apple Silicon no longer needs Rosetta.
- `install.sh` now writes the native messaging manifest to the
  Thunderbird-specific path:
  `~/Library/Application Support/Thunderbird/NativeMessagingHosts/com.attachclip.host.json`
  (previously only the Firefox/Mozilla/ path was written, which
  Thunderbird does not scan).
- `uninstall.sh` mirrored to clean both Thunderbird/ and Mozilla/
  manifests.
- Post-install banner now points to the correct
  `about:debugging#/runtime/this-mv3` URL for Thunderbird 128+.

## [0.1.0-alpha.1] — 2026-07-01

> First open-source cut. macOS only. Thunderbird 128+ (Manifest V3).
> No production deployment yet.

### Added
- WebExtension (MV3) with two context menus:
  `Copy Attachment as File` and `Copy All Attachments as Files`.
- macOS Swift helper (`attachclip-host`) implementing the native
  messaging JSON protocol.
- Cache directory at `~/Library/Caches/AttachClip/sessions/<sessionId>/`
  with 72-hour TTL cleanup.
- Sanitizer that strips control characters and Windows-reserved names.
- Documentation: architecture, native messaging, threat model,
  troubleshooting, upstream proposal, full testing matrix.
- GitHub workflows: CI (JS lint, Markdown lint, Swift build) and
  release (`.xpi` + helper zip on `v*` tags).
- Issue templates: bug, feature request, compatibility report.
- PR checklist enforcing no-telemetry, no-email-mutation, no-extra-perms.

### Known limitations
- No icons yet (manifest omits the `icons` field). Add before AMO
  submission. Tracked in `docs/implementation-report.md`.
- Helper binary is **not** code-signed / notarized. macOS Gatekeeper
  may prompt the user the first time.
- Cache TTL is fixed at 72h. There's no UI yet; cleanup runs on
  every helper start.
- No configuration surface. Defaults are baked into both sides.

### Smoke-test verification (host)
The macOS helper was built and exercised end-to-end on a real
host during the alpha.1 cut. `scripts/smoke_test.py` round-trips
a 6 KB blob through:

1. `begin_session` → real `sessionId` returned
2. `begin_file` → real cache file created
3. `write_chunk` × 7 (1024 byte pieces) → byte-for-byte round trip
4. `end_file` → `size: 6600` matches input
5. `commit_clipboard` → `NSPasteboard.writeObjects` accepted with
   `count: 1`
6. `clear_cache` (hours=0) → removes the session and reports bytes
   reclaimed

See `docs/implementation-report.md` § 9 for the full transcript.

### Bugs found and fixed during alpha.1 cut
- `main.swift` — `let len` passed `&len` to `Data(bytes:count:)`
  → switched to `var len`.
- `main.swift` — `(r["error"] as! [...])["detail"] = ...`
  rejected by Swift 6 type checker → build the dict first.
- `CacheStore.swift` — `FileHandle(forWritingTo:)` requires the file
  to exist; first write returned `IO_ERROR`.
  Fixed by `FileManager.createFile(atPath:contents:attributes:)`
  before opening the handle.

### Security
- Initial threat model published (`docs/threat-model.md`).
- Native messaging manifest locks to extension ID
  `attachclip-thunderbird@example.com` (placeholder until AMO assigns
  a permanent ID).

[unreleased]: https://example.com/compare/v0.1.0-alpha.1...HEAD
[0.1.0-alpha.1]: https://example.com/releases/tag/v0.1.0-alpha.1
