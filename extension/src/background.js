/*
 * AttachClip for Thunderbird — background.js
 * ------------------------------------------
 * Orchestrator. Wires together:
 *   menus.onClicked       -> determine what the user picked
 *   attachmentReader      -> fetch the File blobs
 *   nativeClient          -> stream them to the helper via Native Messaging
 *   notifications         -> surface success / failure to the user
 *
 * Also exposes a programmatic "clear cache" command via the browser
 * action (omitted from this alpha) and a heartbeat `ping` from the
 * browser console.
 */

(function () {
  "use strict";

  const { attachmentReader, nativeClient, notifications } = self.attachclip;
  const SKIP_ORIGIN_CHECK = false; // future-proof hook for skip-iframe

  // ---- Menu click -> copy pipeline ----

  async function copySingle(tabId, partName) {
    return attachmentReader.readSingleAttachment(tabId, partName)
      .then((file) => nativeClient.copyAttachments([file]));
  }

  async function copyAll(tabId) {
    return attachmentReader.readAllAttachments(tabId)
      .then((files) => {
        if (files.length === 0) {
          notifications.showError("ATTACHMENT_READ_FAILED", "no attachments");
          return null;
        }
        return nativeClient.copyAttachments(files);
      });
  }

  async function handleCopyRequest(req) {
    const tabId = req.tabId;
    if (!tabId) {
      console.warn("[AttachClip] menu click without tabId, aborting");
      return;
    }

    let resolved = [];
    try {
      if (req.mode === "all") {
        resolved = await copyAll(tabId);
      } else {
        const one = await copySingle(tabId, req.singlePart);
        resolved = [one];
      }

      if (!resolved) return;
      // Success path
      const sample = resolved && resolved[0] && resolved[0].name;
      const count = req.mode === "all"
        ? (resolved && Array.isArray(resolved) ? resolved.length : 0)
        : 1;
      await notifications.showSuccess(count, sample);
    } catch (err) {
      console.error("[AttachClip] copy pipeline failed:", err);
      const reason = err && err.reason ? err.reason : "UNKNOWN";
      const detail = err && err.message ? err.message : "";
      await notifications.showError(reason, detail);
    }
  }

  // ---- Runtime message bridge ----

  browser.runtime.onMessage.addListener((msg, sender, sendResponse) => {
    if (!msg || typeof msg !== "object") return false;
    if (msg.kind === "attachclip-copy-request") {
      handleCopyRequest(msg).finally(() => {
        // Always send a response so the caller doesn't hang.
        try { sendResponse({ ok: true }); } catch (_) { /* ignore */ }
      });
      return true; // async response
    }
    if (msg.kind === "attachclip-ping-helper") {
      nativeClient.ping()
        .then((r) => sendResponse({ ok: true, echo: r }))
        .catch((e) => sendResponse({ ok: false, error: e.reason || e.message }));
      return true;
    }
    if (msg.kind === "attachclip-clear-cache") {
      nativeClient.clearCache(msg.olderThanHours || 72)
        .then((r) => sendResponse({ ok: true, result: r }))
        .catch((e) => sendResponse({ ok: false, error: e.reason || e.message }));
      return true;
    }
    return false;
  });

  // ---- Lifecycle: re-register menus on install/update/startup ----

  browser.runtime.onInstalled.addListener(() => {
    console.debug("[AttachClip] onInstalled");
    // menus.js self-registers; nothing to do here yet.
  });

  browser.runtime.onStartup.addListener(() => {
    console.debug("[AttachClip] onStartup");
  });

  // ---- Heartbeat from the dev console: AttachClip.ping() ----
  self.AttachClip = Object.freeze({
    ping: () => nativeClient.ping().catch((e) => ({ ok: false, error: e.reason || e.message })),
    clearCache: (h) => nativeClient.clearCache(h || 72),
    version: "0.1.0-alpha.1",
  });

  // Surfacing missing-origin context for future auditing
  if (SKIP_ORIGIN_CHECK) console.debug("[AttachClip] origin check skipped");
})();
