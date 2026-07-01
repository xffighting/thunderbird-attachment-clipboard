# Native Messaging protocol

AttachClip uses the standard
[Mozilla Native Messaging](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_manifests)
stdio-framed JSON protocol. Every message in either direction is
encoded as:

```
+----------------------------------------------------------+
| uint32_t length (little-endian) | JSON bytes (UTF-8)     |
| 4 bytes                        | length bytes            |
+----------------------------------------------------------+
```

Requests are framed by the WebExtension; the helper echoes back
responses in the same format.

## Connection

```js
const port = messenger.runtime.connectNative("com.attachclip.host");
```

The host's binary path is fixed in the manifest at
`~/Library/Application Support/Mozilla/NativeMessagingHosts/com.attachclip.host.json`.

## Correlation

Every request carries:

```json
{ "nonce": "string", "type": "...", "v": 1, ... }
```

The helper echoes the `nonce` back in its response so the
WebExtension can correlate asynchronous responses. We ignore
unsolicited messages.

## Message types

### `ping`

```jsonc
// →
{ "type": "ping", "v": 1, "nonce": "abc" }
// ←
{ "ok": true, "type": "pong", "v": 1, "build": "0.1.0-alpha.1", "nonce": "abc" }
```

Used by the WebExtension to detect a missing helper without copying.

### `begin_session`

```jsonc
// →
{ "type": "begin_session", "v": 1, "nonce": "abc" }
// ←
{
  "ok": true,
  "type": "session_started",
  "sessionId": "s_UUID",
  "sessionDir": "/Users/.../Library/Caches/AttachClip/sessions/s_UUID/",
  "expiresAt": "2026-07-04T13:00:00Z",
  "nonce": "abc"
}
```

A session is a directory under `~/Library/Caches/AttachClip/sessions/`.
It expires after **72 hours** by default.

### `begin_file`

```jsonc
// →
{
  "type": "begin_file", "v": 1, "nonce": "abc",
  "sessionId": "s_UUID",
  "fileId":     "f_random",
  "suggestedName": "Invoice-2026Q2.pdf",
  "contentType": "application/pdf",
  "size": 1234567
}
// ←
{
  "ok": true, "type": "file_started", "fileId": "f_random",
  "finalName": "Invoice-2026Q2.pdf",
  "path": "/.../sessions/s_UUID/Invoice-2026Q2.pdf",
  "nonce": "abc"
}
```

The helper applies its FilenameSanitizer (mirroring the JS side)
and reserves a non-colliding name inside the session directory.

### `write_chunk`

```jsonc
// →
{
  "type": "write_chunk", "v": 1, "nonce": "abc",
  "sessionId": "s_UUID",
  "fileId": "f_random",
  "chunkId": 0,
  "data": "<base64 of ≤524288 bytes>"
}
// ←
{ "ok": true, "type": "chunk_written", "fileId": "f_random",
  "bytesWritten": 524288, "nonce": "abc" }
```

`chunkId` is informational; the helper enforces ordering anyway.
Max payload per chunk is 512 KiB (`nativeClient.CHUNK_BYTES`).
Total request frame is capped at 16 MB on the helper side for
defense against runaway senders.

### `end_file`

```jsonc
// →
{
  "type": "end_file", "v": 1, "nonce": "abc",
  "sessionId": "s_UUID",
  "fileId": "f_random",
  "bytesWritten": 1234567
}
// ←
{
  "ok": true, "type": "file_closed", "fileId": "f_random",
  "path": "...", "size": 1234567, "nonce": "abc"
}
```

To abort an in-flight file, send `end_file` with `"abort": true`.
The helper removes the half-written file from disk.

### `commit_clipboard`

```jsonc
// →
{
  "type": "commit_clipboard", "v": 1, "nonce": "abc",
  "sessionId": "s_UUID",
  "fileIds": ["f_random", "f_random2"]
}
// ←
{
  "ok": true, "type": "commit_ok",
  "count": 2,
  "urls": ["/.../file1.pdf", "/.../file2.png"],
  "nonce": "abc"
}
```

The helper:

1. Re-resolves every `fileId` to a path on disk.
2. Calls `NSPasteboard.general.clearContents()`.
3. Calls `NSPasteboard.general.writeObjects(urls as [NSURL])`.
4. Returns the URLs it pasted for the extension's own records.

### `clear_cache`

```jsonc
// →
{ "type": "clear_cache", "v": 1, "nonce": "abc", "olderThanHours": 72 }
// ←
{ "ok": true, "type": "cache_cleared",
  "filesRemoved": 7, "bytesReclaimed": 1234567,
  "nonce": "abc" }
```

Triggered automatically on helper startup. Can also be invoked
manually via `AttachClip.clearCache()` from the DevTools console.

## Error envelope

Any failure returns:

```jsonc
{
  "ok": false,
  "error": {
    "reason": "STRING_REASON_CODE",
    "message": "human-readable summary",
    "detail": "optional extra info"
  },
  "nonce": "abc"
}
```

| `reason`                  | When                                                         |
| ------------------------- | ------------------------------------------------------------ |
| `BAD_REQUEST`             | Missing required fields                                      |
| `BAD_JSON`                | Frame did not parse as a JSON object                         |
| `BAD_ENCODING`            | Base64 chunk was malformed                                   |
| `IO_ERROR`                | Cache file create/append/close failed                        |
| `SESSION_FAILED`          | `begin_session` could not create the directory               |
| `CLIPBOARD_WRITE_FAILED`  | NSPasteboard refused the URLs                                |
| `UNKNOWN_TYPE`            | The helper doesn't recognise the `type` field                |
| `HELPER_RESPONSE_TOO_LARGE`| (Extension-side guard) Response exceeded 1 MB               |

## Frame size limits

| Direction | Limit   | Enforced by                           |
| --------- | ------- | ------------------------------------- |
| Request   | ≤ 16 MB | Helper (`main.swift::readFrame`)      |
| Response  | < 1 MB  | Extension (`nativeClient.send`)       |
| Chunk     | 512 KiB | Extension (`nativeClient.CHUNK_BYTES`)|

## Versioning

`"v": 1` is the protocol version. The helper logs and continues
if it sees a higher `v` (forward-compatible), but returns an
`UNKNOWN_TYPE` error if it sees a `type` it doesn't recognise.
Backward compatibility (older helper serving newer extension) is
explicitly unsupported during the alpha.
