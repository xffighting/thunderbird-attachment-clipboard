# Manual testing matrix

> Every entry must be ticked off before a release tag. New targets
> must be added in **alphabetical order** and ratified in
> `ROADMAP.md`.

## How to run a row

1. Send yourself an email containing **two** attachments: one
   small (≤100 KB) PDF and one medium (≥10 MB) ZIP. Add one
   message with three identical attachment names so the
   `uniqueName` resolver kicks in.
2. Open the message in a real mail tab (not the search preview).
3. Trigger the row's "how to paste" action.
4. Verify the result described in the row's "verify" cell.
5. Tick the checkbox (or note the failure mode in a PR comment).

## Status legend

| Symbol | Meaning                              |
| ------ | ------------------------------------ |
| ✅     | Confirmed by ≥1 maintainer            |
| ⚠️     | Inconsistent across versions         |
| ❌     | Fails; tracked in issues             |
| 🆕    | First entry; awaiting review         |

## Targets

| # | Target application          | macOS      | How to paste          | Verify                                | Status |
| - | --------------------------- | ---------- | --------------------- | ------------------------------------- | ------ |
| 1 | Finder                      | 12, 13, 14, 15 | Cmd+V into a window  | Real file appears (icon, not text)     | ✅ |
| 2 | Thunderbird new mail (HTML) | 128+       | Cmd+V in compose      | Attachment auto-inserts               | ✅ |
| 3 | Thunderbird new mail (plain) | 128+      | Cmd+V in compose      | Same — fallback path works            | ✅ |
| 4 | WeChat 4.0+                 | 12 → 15    | Cmd+V over chat input | Drop-down lets user pick "Send as file" | ✅ |
| 5 | WeChat < 4.0                | 12 → 15    | Cmd+V over chat input | Pastes raw text if app too old; warn user | ⚠️ |
| 6 | Lark (飞书) 7.x          | 12 → 15    | Cmd+V over compose    | "upload as file" accepted              | ✅ |
| 7 | Lark (飞书) 6.x          | 12         | Cmd+V over compose    | Same                                  | ⚠️ |
| 8 | DingTalk (钉钉) 7.x      | 12 → 15    | Cmd+V over compose    | Skip crop, accepts as file            | ✅ |
| 9 | Slack 4.x                   | 12 → 15    | Cmd+V in channel      | Pastes inline + as attachment         | ✅ |
|10 | Slack 5.x                   | 13, 14, 15 | Cmd+V in channel      | Pastes inline + as attachment         | ✅ |
|11 | Mail (Apple) 16+            | 12 → 15    | Cmd+V in compose      | Auto-attaches                         | ✅ |
|12 | Notes (Apple) 14+           | 12 → 15    | Cmd+V into note       | File reference icon + click-to-reveal  | ✅ |
|13 | Preview (Apple) 11+         | 12 → 15    | Cmd+V into window     | Opens file directly                   | ✅ |
|14 | Microsoft Outlook 16.7x     | 12, 13, 14 | Cmd+V in compose      | Drag-drop equivalent                  | ⚠️ |
|15 | Microsoft Teams 2.x         | 12 → 15    | Cmd+V in chat         | Skips the "paste as link" prompt       | ⚠️ |
|16 | TextEdit                    | 12 → 15    | Cmd+V into doc        | Pastes icon — drag-drop equivalent    | 🆕  |

## Edge cases

| # | Scenario                                            | Expected                                       | Status |
| - | --------------------------------------------------- | ---------------------------------------------- | ------ |
| E1 | One attachment with `contentType: text/x-moz-deleted` (deleted placeholder) | Skipped silently, no toast                     | ✅ |
| E2 | Three attachments with the same name                | All copy, last one gets ` (2)` then ` (3)` suffix | ✅ |
| E3 | Filename with embedded `/`                          | Sanitized to `_` before writing                | ✅ |
| E4 | Filename with embedded control char (e.g. \x07)     | Stripped                                       | ✅ |
| E5 | 1.5 GB single file                                  | Copies, takes ~10s on Apple M2 / NVMe         | ✅ |
| E6 | User cancels Cmd+V (closes Finder before paste)     | Cache entry persists to TTL                   | ✅ |
| E7 | User clears pasteboard manually after copy          | Finder cannot retrieve; expected              | ✅ |
| E8 | Helper binary removed mid-session                   | Native port errors out, "TIMEOUT" toast       | ⚠️ |
| E9 | `~/Library/Caches/AttachClip/` not writable         | IO_ERROR toast, no partial write               | ✅ |
| E10| Two Thunderbird profiles active simultaneously     | Each uses its own extension ID; manifest namespaced | 🆕 |

## Reporting a new target

If you want to add a row, please:

1. Test with a 100 KB PDF **and** a 10 MB ZIP.
2. Try both single and "all attachments" right-click paths.
3. Capture the target app's version, macOS version, and a screen
   recording if the UI path was non-obvious.
4. Open a PR adding the row with `🆕` in the status column and
   link to your test commit.

We will accept rows that satisfy all three before flipping `🆕` to
`✅`.

## CI coverage

This matrix is **manual-only**. CI runs `swift build` and
`eslint`, but cannot verify paste targets. Please re-run the
relevant rows before requesting review on any change to
`ClipboardWriter.swift` or `nativeClient.js`.
