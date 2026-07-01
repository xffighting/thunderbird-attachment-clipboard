# Threat model

This document is the canonical reference for what AttachClip
mitigates and what it intentionally does **not** mitigate.
Reviewers should challenge additions here as protocol changes
land.

## 1.  Trust zones

```
+----------------------------------------------------------+
|         LOCAL MACHINE — "trusted, single principal"      |
|                                                          |
|   +-----------------+      +-------------------------+   |
|   | Thunderbird     |      | macOS pasteboard        |   |
|   | + AttachClip    |      | + apps that paste       |   |
|   |   WebExtension  |      |   (Finder, WeChat, ...) |   |
|   |   (MV3)         |      |                         |   |
|   +--------+--------+      +-------------------------+   |
|            ^ stdio JSON                                |
|            v                                           |
|   +-----------------+                                  |
|   | attachclip-host |                                  |
|   | (Swift binary)  |                                  |
|   | runs as user    |                                  |
|   +-----------------+                                  |
|                                                          |
+----------------------------------------------------------+
              ^
              | NEVER crosses this boundary in any code path
              |
+----------------------------------------------------------+
|         NETWORK / THIRD-PARTY PROCESSES                |
+----------------------------------------------------------+
```

AttachClip **never** sends data outside the local machine's
process boundary. There is no transport, no socket, no `fetch`.

## 2.  Actors and capabilities

| Actor                          | Capabilities                                       | Trust       |
| ------------------------------ | -------------------------------------------------- | ----------- |
| Local user (the operator)      | Anything                                            | Trusted     |
| Thunderbird                    | Executes the WebExtension                          | Trusted     |
| attachclip-host (helper)       | File IO in `~/Library/Caches/AttachClip/`, pasteboard access | Trusted |
| Local paste-target apps       | Read pasteboard on user Cmd+V                       | Trusted     |
| Another WebExtension with same ID | Native messaging port collision                  | Treated as malicious |
| Co-resident process            | Read pasteboard, read user cache                   | Untrusted   |
| Remote attacker                | Network reach only                                 | Untrusted   |

## 3.  Threats considered

### T1. Helper uploads attachment to attacker server
**Status:** Out of scope — see `nettop -p attachclip-host` in the
acceptance test. We have no code path that opens a socket. Will
fail review if anyone adds network APIs in a PR.

### T2. Filename collision writes attacker content over user content
**Status:** Mitigated.

- Filenames are sanitized on both sides (JS + Swift).
- Within a single session the helper reserves non-colliding names
  via `reserveName`, mirroring the JS `uniqueName`.
- Cache directory is created by the helper with `0700` permissions
  and is owned by `$USER`. Other users cannot reach in.

### T3. Path traversal via crafted filename
**Status:** Mitigated.

The sanitizer strips `/` and `\` characters. After sanitization
the name contains no path separators. Verified in unit tests
(`FilenameSanitizerTests` — see extension tests).

### T4. Race: copy → paste → paste again within milliseconds
**Status:** Mitigated.

The pasteboard is `clearContents()` + `writeObjects([...])`. Two
parallel copies serialize on the single-session helper actor.
The second copy wins. We document this in the user-facing note
in README.

### T5. Native messaging manifest injection (untrusted origin)
**Status:** Mitigated.

The rendered manifest contains an explicit
`allowed_extensions` list that locks the helper to the real
extension ID. A second extension cannot reach the helper even
if it knows the host name.

### T6. Buffer overrun from a malicious native messaging frame
**Status:** Mitigated.

`main.swift::readFrame` enforces a 16 MB cap on inbound frames
and rejects zero-length ones. Outbound responses are < 1 MB
(extension-side guard).

### T7. Helper binary tampering (attacker replaces the file)
**Status:** Out of scope (system integrity).

We `chmod 0755` the binary at install time, but don't ship
notarization in 0.1.0. Documented as a v0.5.0 milestone.

### T8. Email tampering via the WebExtension
**Status:** Mitigated by permissions surface.

`messenger.permissions.request` is never called. The manifest
declares exactly:
- `messagesRead`
- `nativeMessaging`
- `contextMenus`
- `notifications`
- `menus`

It does **not** declare:
- `messagesModify`
- `messagesUpdate`
- `mailTabs`
- `compose`
- `accountsRead`
- `<all_urls>` / `host_permissions`

### T9. Privacy disclosure in support requests
**Status:** Operational.

We instruct users in [SUPPORT.md](../SUPPORT.md) to redact
pasteboard contents and to use synthetic test attachments.
Confirmed by bug template.

### T10. Lengthy attachments filling disk
**Status:** Mitigated by TTL.

72-hour cleanup runs at every helper startup. There is no
in-session cap yet — tracked as a v0.4.0 item.

## 4.  Out of scope (we will not mitigate)

| Scenario                                     | Why                                |
| -------------------------------------------- | ---------------------------------- |
| Zero-day in NSPasteboard internals           | Apple-supplied, sandboxed          |
| Co-resident keylogger spying Cmd+V            | User-space OS compromise            |
| RAM-resident attachments being read by debuggers | Reachable only with root + debugger |
| Thunderbird itself exfiltrating to IMAP      | Out of our control                 |

## 5.  Review trigger

Update this document when:

- The wire protocol gains a new verb.
- The cache directory layout changes.
- The WebExtension adds a permission.
- The helper gains a new external side effect (network, IPC, etc).
