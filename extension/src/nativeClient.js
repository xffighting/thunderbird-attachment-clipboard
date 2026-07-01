/*
 * AttachClip for Thunderbird — nativeClient.js
 * ---------------------------------------------
 * Thin wrapper around `messenger.runtime.connectNative("com.attachclip.host")`.
 *
 * Wire protocol (see docs/native-messaging.md):
 *   -> {type:"ping"}
 *   -> {type:"begin_session"}
 *   -> {type:"begin_file", sessionId, fileId, suggestedName, contentType, size}
 *   -> {type:"write_chunk", sessionId, fileId, chunkId, data:base64}    (512KB max)
 *   -> {type:"end_file",   sessionId, fileId, sha256?}
 *   -> {type:"commit_clipboard", sessionId, fileIds:[...]}
 *   -> {type:"clear_cache", olderThanHours:72}
 *
 * Each roundtrip uses a `nonce` for correlation; the helper echoes it back.
 */

(function (root) {
  "use strict";

  const HOST_NAME = "com.attachclip.host";
  const CHUNK_BYTES = 512 * 1024;          // 512KB per write_chunk
  const MAX_HELPER_RESPONSE_BYTES = 1_048_576;  // < 1MB hard cap (per spec)

  // ---- Low-level port management ----
  let port = null;

  function ensurePort() {
    if (port) return port;
    try {
      port = messenger.runtime.connectNative(HOST_NAME);
    } catch (err) {
      throw Object.assign(new Error("HELPER_NOT_INSTALLED"), {
        cause: err, reason: "HELPER_NOT_INSTALLED",
      });
    }
    port.onDisconnect.addListener(() => {
      const err = messenger.runtime.lastError;
      if (err) console.warn("[AttachClip] native port disconnected:", err);
      port = null;
    });
    return port;
  }

  function disconnectPort() {
    try { if (port) port.disconnect(); } catch (_) { /* ignore */ }
    port = null;
  }

  // ---- Pending RPCs keyed by nonce ----
  const pending = new Map();

  function installPortListener(p) {
    if (p.__attachclipWired) return;
    p.__attachclipWired = true;
    p.onMessage.addListener((msg) => {
      if (!msg || typeof msg !== "object") return;
      const key = msg.nonce;
      const waiter = key != null ? pending.get(key) : null;
      if (waiter) {
        pending.delete(key);
        clearTimeout(waiter.timer);
        waiter.resolve(msg);
      } else {
        console.debug("[AttachClip] unsolicited native msg:", msg);
      }
    });
  }

  /**
   * Send a request, get a response.  Throws HELPER_NOT_INSTALLED if the
   * runtime refuses to connect, TIMEOUT if the helper stalls, and any
   * explicit `error` field the helper sends becomes a thrown Error.
   */
  function send(message, timeoutMs = 15_000) {
    const p = ensurePort();
    installPortListener(p);

    const nonce = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
    const payload = Object.assign({ nonce }, message);

    const responseSizeGuard = (raw) => {
      const approx = JSON.stringify(raw || {}).length;
      if (approx > MAX_HELPER_RESPONSE_BYTES) {
        throw new Error("HELPER_RESPONSE_TOO_LARGE");
      }
    };

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        pending.delete(nonce);
        disconnectPort();
        const e = new Error("Helper did not respond in time");
        e.reason = "TIMEOUT";
        reject(e);
      }, timeoutMs);

      pending.set(nonce, {
        resolve: (raw) => {
          try {
            responseSizeGuard(raw);
          } catch (e) {
            reject(e);
            return;
          }
          if (raw && raw.error) {
            const err = new Error(raw.error.message || "helper error");
            err.reason = raw.error.reason || "UNKNOWN";
            err.detail = raw.error.detail;
            reject(err);
            return;
          }
          resolve(raw);
        },
      });

      try {
        p.postMessage(payload);
      } catch (err) {
        pending.delete(nonce);
        clearTimeout(timer);
        reject(err);
      }
    });
  }

  // ---- High-level copy pipeline ----

  async function ping() {
    return send({ type: "ping", v: 1 });
  }

  function bytesToBase64(uint8) {
    let bin = "";
    const CHUNK = 0x8000;
    for (let i = 0; i < uint8.length; i += CHUNK) {
      bin += String.fromCharCode.apply(
        null, uint8.subarray(i, Math.min(i + CHUNK, uint8.length))
      );
    }
    return btoa(bin);
  }

  async function copyAttachments(resolvedFiles) {
    if (!Array.isArray(resolvedFiles) || resolvedFiles.length === 0) {
      throw new Error("NOTHING_TO_COPY");
    }

    // 1. Begin session
    const session = await send({ type: "begin_session", v: 1 });
    if (!session || !session.sessionId) {
      throw new Error("Helper did not return a sessionId");
    }
    const sessionId = session.sessionId;

    try {
      // 2. Begin + chunk + end each file
      for (const file of resolvedFiles) {
        const fileId = `f_${Math.random().toString(36).slice(2, 10)}`;
        file.__attachclipFileId = fileId;

        await send({
          type: "begin_file",
          v: 1,
          sessionId,
          fileId,
          suggestedName: file.name,
          contentType: file.contentType,
          size: file.size,
        });

        const buf = new Uint8Array(await file.blob.arrayBuffer());
        let offset = 0;
        let chunkId = 0;
        while (offset < buf.length) {
          const slice = buf.subarray(offset, offset + CHUNK_BYTES);
          await send({
            type: "write_chunk",
            v: 1,
            sessionId,
            fileId,
            chunkId,
            data: bytesToBase64(slice),
          });
          offset += slice.length;
          chunkId++;
        }

        await send({
          type: "end_file",
          v: 1,
          sessionId,
          fileId,
          bytesWritten: buf.length,
        });
      }

      // 3. Commit clipboard
      const commit = await send({
        type: "commit_clipboard",
        v: 1,
        sessionId,
        fileIds: resolvedFiles.map((f) => f.__attachclipFileId),
      });
      return commit;
    } catch (err) {
      // Best-effort abort so the helper can GC the half-written session.
      try {
        await send({
          type: "end_file",
          v: 1,
          sessionId,
          fileId: "_ABORT_",
          bytesWritten: 0,
          abort: true,
        });
      } catch (_) { /* ignore */ }
      throw err;
    }
  }

  async function clearCache(olderThanHours = 72) {
    return send({ type: "clear_cache", v: 1, olderThanHours });
  }

  root.attachclip = root.attachclip || {};
  root.attachclip.nativeClient = {
    ping,
    copyAttachments,
    clearCache,
    CHUNK_BYTES,
    HOST_NAME,
  };
})(typeof self !== "undefined" ? self : this);
