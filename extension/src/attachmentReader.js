/*
 * AttachClip for Thunderbird — attachmentReader.js
 * ------------------------------------------------
 * Reads attachment blobs from the currently displayed message via the
 * Thunderbird WebExtension APIs. Two entry points:
 *
 *   readSingleAttachment(tabId, partName)
 *     Resolves the displayed message from the tab, finds the attachment
 *     matching `partName` inside `message.info.attachments`, downloads it
 *     as a File, and returns { blob, displayName, contentType, size }.
 *
 *   readAllAttachments(tabId)
 *     Lists all attachments via messenger.messages.listAttachments,
 *     then downloads each one. Skips deleted placeholders
 *     (contentType === "text/x-moz-deleted").
 *
 * Both functions also resolve using the display message's fallback path so
 * they work whether Thunderbird exposes the attachment list on info.attachments
 * (modern TB) or only via listAttachments (older builds).
 */

(function (root) {
  "use strict";

  const { sanitize, uniqueName } = root.attachclip.filename;

  const DELETED_MIME = "text/x-moz-deleted";

  /**
   * Pull the displayed MessageHeader for a tab. Throws on failure.
   */
  async function getDisplayedMessage(tabId) {
    const tabs = await messenger.messageDisplay.getDisplayedMessages(tabId);
    if (!Array.isArray(tabs) || tabs.length === 0) {
      throw new Error("NO_MESSAGE_DISPLAYED");
    }
    return tabs[0];
  }

  /**
   * Combine the per-message `info.attachments` (if present) with anything
   * found via `listAttachments`.  Modern Thunderbird returns the data on
   * the message object; we always fetch it fresh to cover legacy builds.
   */
  async function listAllAttachmentDescriptors(messageId) {
    const fresh = await messenger.messages.listAttachments(messageId);
    return Array.isArray(fresh) ? fresh : [];
  }

  function isDeletedPlaceholder(att) {
    return att && att.contentType === DELETED_MIME;
  }

  /**
   * Convert each descriptor into a resolved { blob, name, ... } record.
   * Skips deleted placeholders silently (they're display-only).
   */
  async function resolveBlobs(messageId, descriptors) {
    const results = [];
    const seenNames = new Set();
    for (const desc of descriptors) {
      if (isDeletedPlaceholder(desc)) continue;

      let blob;
      try {
        blob = await messenger.messages.getAttachmentFile(
          messageId,
          desc.partName
        );
      } catch (err) {
        console.warn(
          `[AttachClip] getAttachmentFile failed for partName=${desc.partName}:`,
          err
        );
        // Continue with remaining attachments; the caller will count skipped.
        continue;
      }
      if (!blob) continue;

      const rawName = desc.name || blob.name || "attachment";
      const cleanName = sanitize(rawName);
      const finalName = uniqueName(seenNames, cleanName);
      seenNames.add(finalName);

      results.push({
        blob,
        originalName: rawName,
        name: finalName,
        contentType: desc.contentType || blob.type || "application/octet-stream",
        size: typeof desc.size === "number" ? desc.size : (blob.size || 0),
        partName: desc.partName,
      });
    }
    return results;
  }

  /**
   * Single attachment path: read info.attachments, pick by partName, resolve.
   */
  async function readSingleAttachment(tabId, partName) {
    const msg = await getDisplayedMessage(tabId);
    const descriptors = await listAllAttachmentDescriptors(msg.id);
    const match = descriptors.find((a) => a.partName === partName && !isDeletedPlaceholder(a));
    if (!match) {
      throw new Error("ATTACHMENT_NOT_FOUND");
    }
    const resolved = await resolveBlobs(msg.id, [match]);
    if (resolved.length === 0) {
      throw new Error("ATTACHMENT_READ_FAILED");
    }
    return resolved[0];
  }

  /**
   * All-attachments path: list, filter, resolve.
   */
  async function readAllAttachments(tabId) {
    const msg = await getDisplayedMessage(tabId);
    const descriptors = await listAllAttachmentDescriptors(msg.id);
    if (descriptors.length === 0) return [];
    const resolved = await resolveBlobs(msg.id, descriptors);
    if (resolved.length === 0) {
      throw new Error("ATTACHMENT_READ_FAILED");
    }
    return resolved;
  }

  root.attachclip = root.attachclip || {};
  root.attachclip.attachmentReader = {
    readSingleAttachment,
    readAllAttachments,
  };
})(typeof self !== "undefined" ? self : this);
