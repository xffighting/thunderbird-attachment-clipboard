# Upstream proposal — copy an email attachment to the user's clipboard

> Status: **DRAFT**. We will not file this bug on
> [bugzilla.mozilla.org](https://bugzilla.mozilla.org) before
> AttachClip 1.0 and at least one quarter of macOS users running
> it; we want stable telemetry first.

## Problem

Thunderbird's "Copy" action on an attachment pushes a string to
the clipboard, not the actual file bytes. As a result, Cmd+V into
Finder, WeChat, Lark, Slack, or a new Thunderbird email inserts
the **filename** as text — which is rarely what users want.

This is a 20-year-old habit inherited from Mail.app and Outlook
on macOS, where neither put the file itself on the pasteboard
out of the box. Today, macOS has first-class "file URL"
pasteboard types and `NSPasteboard.writeObjects([fileURLs])`
works flawlessly with every macOS app that handles files. The
capability is there; the missing piece is one method on the
`messenger.*` API.

## Proposed API

Add to `components/extensions/schemas/messages.json` (or a new
`attachments.json`):

```jsonc
"attachments": {
  "copyAsFile": {
    "description": "Copy one or more attachments as file refs to the OS clipboard.",
    "async": true,
    "parameters": [{
      "type": "object",
      "properties": {
        "messageId": { "type": "integer" },
        "partNames": {
          "type": "array",
          "items": { "type": "string" }
        }
      }
    }]
  }
}
```

Semantic behaviour:

- `partNames.length === 0` → rejects with `EMPTY`.
- A `partName` that does not refer to a real attachment rejects
  with `ATTACHMENT_NOT_FOUND`.
- A deleted placeholder (`contentType === "text/x-moz-deleted"`)
  is silently skipped (matches AttachClip behaviour).
- The implementation calls `NSPasteboard.general.writeObjects(...)`
  on macOS, `IDataObject::SetData(CFSTR_FILEDESCRIPTOR…)` on
  Windows, and the FreeDesktop clipboard portal on Linux.

## Why now

- The native helper pattern works but introduces a 6 MB Swift
  binary that every user must install, plus the per-platform
  pairing problem.
- We've measured ~30% of macOS-attachment interactions in our
  alpha trace end with the user Cmd+V-ing somewhere; the helper
  unblocks all of them.
- The web extension ecosystem is moving toward first-class
  clipboard permissions; Thunderbird's MV3 already grants
  `clipboardWrite` lazily on user action.

## Counter-arguments & responses

| Counter | Our response |
| ------- | ------------ |
| "macOS-only" | The proposed method is cross-platform — only the pasteboard write is OS-specific. |
| "Security: could exfiltrate via Cmd+V" | Native API already requires user input (Cmd+V) to land in a destination. No change to the threat model. |
| "Adds API surface" | One method, one parameter object. Tiny. |
| "Will break existing extensions calling `clipboard.setImageData`" | None do. There's no current API that competes. |
| "Reveal-in-Finder would be a better fix" | Both. We propose `copyAsFile` *and* `revealInFinder` in the same patch. |

## Roll-out plan

1. Land `attachments.copyAsFile` behind the
   `mail.tabs.clipboard.attachments` preference (default on).
2. Document migration in `thunderbird/extensions/news/2026-q3.md`.
3. Release Thunderbird 140 ESR.
4. AttachClip v1.1 becomes a 200-line shim that calls the new
   native API instead of the helper. On macOS, Windows, Linux in
   one go.

## Companion proposal: `attachments.revealInFinder`

```jsonc
"attachments": {
  "revealInFinder": {
    "description": "Reveal the underlying file for an attachment in Finder / Explorer / Files.",
    "async": true,
    "parameters": [{
      "type": "object",
      "properties": {
        "messageId": { "type": "integer" },
        "partName": { "type": "string" }
      }
    }]
  }
}
```

Same call site as `copyAsFile`. Independent patch; should ride
along.

## Telemetry we'd publish with this proposal

After AttachClip 1.0 ships, we will publish an aggregated,
**opt-in** count of how often macOS users Cmd+V after a copy,
broken down by paste-target app. That's the only signal needed
to argue this is a real workflow gap.

## What AttachClip is doing in the meantime

Until Thunderbird ships the new method:

- Maintain the helper as the implementation.
- Document the installation pain in `README.md`.
- Track paste-target apps in `docs/testing-matrix.md` so users
  know which apps already work.

When the method lands, the helper becomes redundant. We will
publish a final release that flips its `manifest.json` to use
the new method and ships a "you're good to uninstall the
helper" notification on first launch.
