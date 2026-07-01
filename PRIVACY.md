# Privacy Policy

**Short version:** AttachClip does not transmit anything off your
machine. It does not modify your email. It does not log into any
service. It does not collect telemetry.

## What AttachClip sees

When you click **Copy Attachment as File** or **Copy All Attachments
as Files**, the WebExtension side of AttachClip:

1. Reads the **displayed** Thunderbird message headers (subject,
   message-id, account-id) via the standard
   `messageDisplay.getDisplayedMessages` API.
2. Reads each targeted attachment as a `File` blob via
   `messages.getAttachmentFile`.
3. Streams those blobs to the local helper binary over the
   Mozilla-defined **Native Messaging** channel (stdin/stdout JSON,
   see [docs/native-messaging.md](docs/native-messaging.md)).

The helper binary:

1. Writes each blob under
   `~/Library/Caches/AttachClip/sessions/<sessionId>/`.
2. Calls `NSPasteboard.general.writeObjects([fileURLs])`.
3. Returns a short JSON acknowledgement.

That's the whole data path. Nothing crosses a network boundary.

## What AttachClip does NOT do

- ❌ No upload. There is no `fetch`, no `XMLHttpRequest`, no
  `WebSocket`. The extension's `permissions` array deliberately omits
  `<all_urls>` and any `host_permissions`.
- ❌ No telemetry. There is no analytics SDK, no opt-in ping, no
  crash reporter. Errors are surfaced only via the user-visible
  `browser.notifications` channel.
- ❌ No email mutation. We use `messagesRead`, not `messagesModify`,
  never call `messages.update`, never call `messages.delete`, never
  call `mailTabs.setSelectedMessages`. We do not mark messages read.
- ❌ No mail-server contact. The helper does not open TCP / UNIX
  sockets at all — `nettop -p attachclip-host` will show zero outbound
  connections.
- ❌ No third-party file write. Cache files are written **only** into
  the session subdirectory under `~/Library/Caches/AttachClip/`.

## On-disk cache

- Location: `~/Library/Caches/AttachClip/sessions/<sessionId>/`
- Lifetime: 72 hours by default. Cleanup runs on every helper
  startup. There is no UI to override this yet.
- Permissions: directory mode `0700`, files mode `0600`. Other users
  on the same machine cannot read them.
- Deletion: `rm -rf ~/Library/Caches/AttachClip/` removes everything
  immediately. The next helper invocation will recreate an empty
  cache root.

## When you report a bug

If you open a GitHub issue and **attach** a sample email or
attachment to reproduce, please redact sensitive content first — we
will run the reporter against synthetic files. **Do not paste raw
pasteboard contents or live session IDs** into public issues.

## Legal bits

This product is provided "as is", without warranty of any kind.
See [LICENSE](LICENSE) for the full text.

Any change to this policy is published in
[CHANGELOG.md](CHANGELOG.md) and announced in the next GitHub
release notes.
