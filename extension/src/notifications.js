/*
 * AttachClip for Thunderbird — notifications.js
 * ----------------------------------------------
 * All user-visible chrome.notifications calls go through here.
 * Keeps translation strings in one place and prevents accidental
 * system-notification spam.
 */

(function (root) {
  "use strict";

  const ICON_URL = browser.runtime.getURL
    ? "" // filled in lazily (we don't ship icon files yet, see impl report)
    : "";

  function build(notificationId, title, message) {
    const opts = { type: "basic", title, message };
    if (ICON_URL) opts.iconUrl = ICON_URL;
    return { id: notificationId, opts };
  }

  function notify(notificationId, title, message) {
    const { opts } = build(notificationId, title, message);
    return browser.notifications.create(notificationId, opts).catch((err) => {
      console.warn("[AttachClip] notifications.create failed:", err);
    });
  }

  async function showSuccess(count, sampleName) {
    const title = "AttachClip";
    const message = count === 1
      ? `Copied 1 attachment (${sampleName || ""}). Paste with Cmd+V.`
      : `Copied ${count} attachments. Paste with Cmd+V.`;
    await notify("attachclip-success", title, message);
  }

  async function showError(reason, detail) {
    const map = {
      HELPER_NOT_INSTALLED: {
        title: "AttachClip — helper not installed",
        message:
          "Run `./native-host/macos/install.sh` once and restart Thunderbird. " +
          "(See docs/install-macos.md.)",
      },
      ATTACHMENT_READ_FAILED: {
        title: "AttachClip — could not read attachment",
        message:
          "Thunderbird could not provide the file blob. The message may have " +
          "been moved or be partially downloaded.",
      },
      CLIPBOARD_WRITE_FAILED: {
        title: "AttachClip — clipboard write failed",
        message:
          "The helper could not update the macOS pasteboard. Is the binary still " +
          "installed and executable?",
      },
      SESSION_ABORTED: {
        title: "AttachClip — copy aborted",
        message:
          "One or more files failed to write. Nothing was added to the clipboard.",
      },
      TIMEOUT: {
        title: "AttachClip — timed out",
        message:
          "The native helper did not respond in time. Try again; if it persists, " +
          "see docs/troubleshooting.md.",
      },
      UNKNOWN: {
        title: "AttachClip — unexpected error",
        message: "See the browser console (Ctrl+Shift+J) for details.",
      },
    };
    const entry = map[reason] || map.UNKNOWN;
    const extra = detail ? `\n\nDetails: ${detail}` : "";
    await notify("attachclip-error", entry.title, entry.message + extra);
  }

  function clearSuccess() {
    browser.notifications.clear("attachclip-success").catch(() => {});
  }

  root.attachclip = root.attachclip || {};
  root.attachclip.notifications = { showSuccess, showError, clearSuccess };
})(typeof self !== "undefined" ? self : this);
