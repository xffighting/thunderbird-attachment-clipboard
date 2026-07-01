# Architecture

## Big picture

```
 ┌─────────────────────────────────────────────────────────────────────┐
 │  Thunderbird 128+ (MV3 WebExtension)                                │
 │                                                                     │
 │  ┌────────────┐  click   ┌──────────────────┐                       │
 │  │ menus.js   │ ───────► │ background.js    │                       │
 │  └────────────┘          │  orchestrator    │                       │
 │                          └─────────┬────────┘                       │
 │  ┌──────────────────────┐          │                                │
 │  │ attachmentReader.js  │ ◄────────┤  read Single / All             │
 │  └─────────┬────────────┘          │                                │
 │            │ Blobs                 │                                │
 │            ▼                       │                                │
 │  ┌──────────────────────┐          │                                │
 │  │  nativeClient.js     │ ◄────────┤  send / recv via port          │
 │  └─────────┬────────────┘          │                                │
 │            │ runtime.connectNative │                                │
 └────────────┼───────────────────────┼────────────────────────────────┘
              │ stdio (4-byte length + JSON)
              ▼
 ┌─────────────────────────────────────────────────────────────────────┐
 │  attachclip-host  (Swift)                                           │
 │                                                                     │
 │  ┌──────────────┐    ┌──────────────┐    ┌─────────────────────┐    │
 │  │ main.swift   │ →  │ NativeMessage│ →  │ CacheStore          │    │
 │  │  stdin/stdout│    │   .swift     │    │  ~/Library/Caches/  │    │
 │  │  dispatcher  │    │  parse / fmt │    │  AttachClip/sessions│    │
 │  └──────────────┘    └──────────────┘    └─────────┬───────────┘    │
 │                                                     │ urls          │
 │                                                     ▼               │
 │                                            ┌──────────────────┐     │
 │                                            │ ClipboardWriter  │     │
 │                                            │  NSPasteboard    │     │
 │                                            │  .writeObjects() │     │
 │                                            └─────────┬────────┘     │
 │                                                      │              │
 └──────────────────────────────────────────────────────┼──────────────┘
                                                        ▼
                              macOS pasteboard (kPasteboardTypeFileURL)
                                        │
                                        ▼
                          Finder / WeChat / Lark / Slack / new mail
```

## Component responsibilities

| Component         | Owns                                                  | Doesn't own                       |
| ----------------- | ----------------------------------------------------- | --------------------------------- |
| `menus.js`        | Two context menu entries                              | Reading the attachment            |
| `background.js`   | Wiring menu click → reader → client → notification    | Anything filesystem- or IO-level  |
| `attachmentReader`| Resolving File blobs from the displayed message       | The clipboard                     |
| `nativeClient`    | Lifecycle of a Native Messaging port, message framing | Path safety, sanitization, cache  |
| `notifications`   | `browser.notifications.create/clear`                  | Console error reporting           |
| `filename`        | Filename sanitisation + de-collision                  | File existence checks             |
| `ClipboardWriter` | `NSPasteboard.writeObjects`                           | Cache writes                      |
| `CacheStore`      | Session directory layout, TTL cleanup, file handle    | Pasteboard                        |
| `FilenameSanitizer`| Mirror of `filename.js` for Swift side               | Anything outside names            |

## Data flow

### Single attachment

```
[user right-clicks attachment]
  → menus.onClicked (single)
  → background.js handleCopyRequest({mode:"single", singlePart})
  → attachmentReader.readSingleAttachment(tabId, partName)
      ├─ messageDisplay.getDisplayedMessages
      └─ messages.listAttachments + messages.getAttachmentFile
  → nativeClient.copyAttachments([file])
      ├─ begin_session
      ├─ for file: begin_file → (write_chunk)* → end_file
      └─ commit_clipboard  → NSPasteboard.writeObjects([url])
  → notifications.showSuccess(1, file.name)
```

### All attachments

Same as above except `mode:"all"` triggers
`attachmentReader.readAllAttachments`, which uses
`listAttachments(messageId)` then loops, filtering
`contentType === "text/x-moz-deleted"`.

## Cache TTL strategy

Every helper startup runs `clearStale(olderThanHours: 72)`:

```
sessionDir
  └─ mtime > now - 72h   → keep
  └─ mtime ≤ now - 72h   → rm -rf + remove from sessionDirs map
```

This is **lazy cleanup** — files linger slightly past 72h if the
helper hasn't run. We never block a copy on cleanup. Files written
by a successful copy are guaranteed not to be removed before the
user actually pastes; we only remove sessions whose oldest file is
older than the cutoff.

The TTL is currently hard-coded to 72 hours. A `browser.storage`
setting will override it in v0.4.0 (see `ROADMAP.md`).

## Failure model

| Where            | Failure mode              | User-visible action                              |
| ---------------- | ------------------------- | ------------------------------------------------ |
| `listAttachments`| Exception thrown          | `notifications.showError("ATTACHMENT_READ_FAILED")` |
| `getAttachmentFile` partway | per-file exception, others continue | report count of skipped attachments in toast |
| Native connect   | Helper missing            | `notifications.showError("HELPER_NOT_INSTALLED")` |
| Native RTT > 15s | Watchdog timer            | `notifications.showError("TIMEOUT")`             |
| Helper clipboard | Refuses payload           | `notifications.showError("CLIPBOARD_WRITE_FAILED")` |
| Helper IO        | Disk full / EPERM         | `notifications.showError("IO_ERROR")`            |

We **never** retry silently on failure. The user always sees a
notification with the reason code.

## Latency budget

| Phase                            | Target   |
| -------------------------------- | -------- |
| Menu click → first byte to helper | < 50 ms  |
| Per-attachment file copy         | < 5 MB/s sustained |
| Helper commit → pasteboard ready | < 100 ms |
| Notification appearance          | < 200 ms |
| **Total, 5 MB single file**      | < 1.5 s  |

Apple Silicon Finder Cmd+V is typically instant once the
pasteboard write returns. The hot path is the file write; on
PCIe SSD it should hold 1 GB/s for sequential writes.
