# Security Policy

## Supported versions

| Version          | Supported            |
| ---------------- | -------------------- |
| `v0.1.x` (alpha) | ✅ best effort        |
| `< 0.1.0`        | ❌ never released     |

AttachClip is alpha-grade software. Expect breaking changes and please
pin to a specific git commit if you depend on it for production work.

## Reporting a vulnerability

**Please do not open a public GitHub issue for security bugs.**

Send a private report to: **security@attachclip.example.com** (PGP
key on request). Use the `bug_report` issue template for non-security
defects only.

We aim to:

- Acknowledge within **3 business days**.
- Provide an initial assessment within **10 business days**.
- Coordinate disclosure so a fix ships before public detail.

### What to include

- Thunderbird version + build id (from `about:support`).
- macOS version + hardware (Apple Silicon / Intel).
- AttachClip version (`git describe`).
- Reproduction steps. If the issue involves an attachment, please
  redact its body; we will reproduce with a synthetic file unless we
  specifically request a sample.
- A capture of `console` errors and any `os_log` lines from
  `log stream --predicate 'subsystem == "com.attachclip.host"'`.

### What we will NOT do

- We will not silently fix. We publish a CVE-compatible note on
  resolution in the relevant GitHub Security Advisory
  (`https://github.com/xffighting/thunderbird-attachment-clipboard/security/advisories`).
- We will not request that you disable security features.

## Threat model

See [docs/threat-model.md](docs/threat-model.md). High-level summary:

- We treat the macOS helper as **honest-but-curious** code that handles
  file blobs. We mitigate by sandboxing (`chmod 0600` on cache files,
  per-session UUID directories, TTL cleanup).
- We treat Thunderbird itself as hostile at worst: the WebExtension
  runs with only `messagesRead`, `nativeMessaging`, and UI
  permissions. No `webRequest`, no `tabs`, no `storage`.
- We treat the local user as the only principal: there is no
  authentication between the helper and the extension. A second
  extension on the same ID could theoretically issue commands.
  Mitigations:
  - The helper refuses any frame whose payload exceeds 16 MB.
  - Cache writes go to a uniquely-named subdirectory; remove impacts
    only that session.
  - We never expose a "read file" verb; commit is one-way.

## Hardening checklist (post-install)

```bash
chmod 0755  "$HOME/.local/bin/attachclip-host"
chmod 0600  "$HOME/Library/Caches/AttachClip" -R   # already 0700 by default
```

If you observe unexpected files in `~/Library/Caches/AttachClip/`
that you did not create, please report them.
