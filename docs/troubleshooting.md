# Troubleshooting

> Each section is a symptom + a checklist.  Run the rows in
> order; the first one that fails is almost always the cause.

## 1. "Helper not installed" notification

Symptom: clicking the menu item shows the AttachClip toast:
*"Run `./native-host/macos/install.sh` once and restart
Thunderbird."*

Checklist:

1. `which attachclip-host`
   - empty → the binary is not on `$PATH`; rerun
     `native-host/macos/install.sh`.
2. `ls "$HOME/Library/Application Support/Mozilla/NativeMessagingHosts/" | grep attachclip`
   - empty → the manifest wasn't written. Re-run `install.sh`
     and watch the output for `Writing native messaging manifest
     to ...`.
3. Did you restart Thunderbird after installing? Yes / no?
   - If no, fully quit and relaunch Thunderbird (Cmd+Q). The
     manifest is read on startup.
4. Are you using a Thunderbird profile that lives elsewhere? Snap
   installed Thunderbird uses `~/snap/thunderbird/common/...`;
   the manifest goes into `$HOME/.mozilla/native-messaging-hosts/`
   for those builds.

## 2. "Timed out" notification

Symptom: a brief pause, then *"The native helper did not respond
in time."*

Checklist:

1. Open **Tools → Developer Tools → Browser Console** and filter
   for `AttachClip`. The error before the timeout is usually the
   real failure.
2. Run the helper manually to confirm it boots:
   ```bash
   attachclip-host
   # Then type this single line and hit Ctrl+D:
   {"type":"ping","v":1,"nonce":"test"}
   # Expected output: {"ok":true,"type":"pong",...}
   ```
3. If the helper exits silently, check:
   ```bash
   log stream --predicate 'subsystem == "com.attachclip.host"' --info --debug
   ```
4. If you just upgraded macOS, Gatekeeper may have quarantined
   the new binary. Force it:
   ```bash
   xattr -dr com.apple.quarantine "$HOME/.local/bin/attachclip-host"
   ```

## 3. Files don't paste as files (paste as plain text)

Symptom: Cmd+V in Finder inserts text. Cmd+V in WeChat shows the
filename as a string.

This means either:

- The target app is too old (see the [`testing-matrix.md`](testing-matrix.md))
  warning columns, OR
- macOS sandboxed the helper and revoked pasteboard access.

Verify with a manual run:

```bash
ls /usr/bin/security   # built-in, noop
attachclip-host <<< '{"type":"ping","v":1,"nonce":"foo"}'
```

If ping succeeds but Finder still pastes text, the issue is in
Finder — restart it (`killall Finder`).

## 4. "Could not read attachment" notification

Cause: Thunderbird could not produce a `File` blob. Common reasons:

- The message is on an IMAP folder that's offline. Reconnect.
- The message is in the search-result preview (not the real
  message tab). Click the message to open it in a real tab.
- The message is in trash. The cleanup job may have deleted
  the body. Skip.

If you suspect a file-size issue:

```bash
ls -lah "$HOME/Library/Caches/AttachClip/sessions/"
```

You should see a `<sessionId>/` directory per copy attempt, with
expected file sizes. If a file is partial, look at the helper's
`os_log` for `IO_ERROR`.

## 5. Stale cache — disk is filling up

Manually clear:

```js
AttachClip.clearCache(0);  // 0 hours = remove everything
```

… in the DevTools console, OR:

```bash
rm -rf "$HOME/Library/Caches/AttachClip"
```

The helper will recreate the directory on next start.

## 6. Path-disallowed error from Mozilla

```
Reading manifest: Native messaging manifest not allowed for ...
```

Means the manifest's `allowed_extensions` list does not match
the actual extension ID. Your Thunderbird is loading the
extension under a different ID (e.g. via about:debugging the ID
is per-session). Re-render the manifest with the right ID, or
declare a permanent ID via `browser_specific_settings.gecko.id`
in `manifest.json` after AMO submission.

## 7. Still stuck?

Open an issue with the [bug template](../.github/ISSUE_TEMPLATE/bug_report.yml),
including:

- `git describe` output (or installed helper version)
- Thunderbird version (from About)
- macOS version + hardware
- Browser-console errors filtered by `AttachClip`
- Helper `os_log` output (see step 2 above)

We aim for a 7-day turnaround during alpha.
