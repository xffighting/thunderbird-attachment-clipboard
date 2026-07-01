# Install on macOS

> Follow these steps on the machine that runs Thunderbird. The
> helper binary installs **per-user** unless you `sudo`.

## Requirements

- macOS 12 Monterey or newer (Apple Silicon or Intel)
- Thunderbird 128.0 or newer
- Xcode 14+ command-line tools (`xcode-select --install`), which
  include `swift` 5.7+

You can verify with:

```bash
swift --version          # Apple Swift version 5.7 (build ...) or newer
/Applications/Thunderbird.app/Contents/MacOS/thunderbird --version
                        # Mozilla Thunderbird 128.x ...
```

## One-shot install

```bash
git clone https://github.com/EXAMPLE/thunderbird-attachment-clipboard.git
cd thunderbird-attachment-clipboard/native-host/macos
./install.sh
```

The script does the following:

| Step | Notes                                                      |
| ---- | ---------------------------------------------------------- |
| 1    | Runs `swift build -c release --triple x86_64-apple-macosx12.0` |
| 2    | Copies the binary to `~/.local/bin/attachclip-host` (or `/usr/local/bin` under sudo) |
| 3    | Sets mode `0755`                                            |
| 4    | Renders the manifest template with the resolved binary path |
| 5    | Writes the manifest to `~/Library/Application Support/Mozilla/NativeMessagingHosts/com.attachclip.host.json` |

> Tip — if `~/.local/bin` is not on your `$PATH`, append it: 
> ```bash
> echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
> ```

## Load the extension in Thunderbird

1. Restart Thunderbird so it re-reads the native messaging
   manifest.
   (Important: Thunderbird caches the host registry on launch.)
2. Open **Tools → Developer Tools → about:debugging** (or
   visit `about:debugging#/runtime/this-firefox` in the address bar).
3. Click **Load Temporary Add-on…** and pick
   `extension/manifest.json` from the cloned repo.
4. The two context menu items appear immediately.

Temporary add-ons are removed when you close Thunderbird.
For a persistent install, see the "Persistent install" section
in [upstream-proposal.md](upstream-proposal.md) — it requires
signing from `addons.thunderbird.net`, which is a v1.0.0 milestone.

## Verify

1. Open any email with at least one attachment.
2. Right-click the attachment → **Copy Attachment as File**.
3. In Finder, hit **Cmd+V**. A real file appears with the
   correct icon and extension.
4. Repeat the right-click on **the message itself**
   (`Copy All Attachments as Files`) and verify with Cmd+V into
   a Slack / WeChat / Lark window.

## Re-running / Repairing

The install script is idempotent. To repair:

```bash
./install.sh           # overwrites both binary and manifest
```

If the helper stops responding, try:

```bash
~/Library/Caches/AttachClip/   # inspect / nuke
rm -rf ~/Library/Caches/AttachClip/
attachclip-host                # run helper directly; type {"type":"ping","v":1}
                               # on stdin (Ctrl-D on a blank line) to see pong
```

If that returns `{"ok":true,"type":"pong",...}` you have a
working helper; the issue is on the Thunderbird side. See
[troubleshooting.md](troubleshooting.md).

## Uninstallation

See [../native-host/macos/uninstall.sh](../native-host/macos/uninstall.sh)
or run it directly:

```bash
./uninstall.sh
```

Don't forget to remove the temporary add-on via `about:debugging`.
