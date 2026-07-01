/*
 * AttachClip for Thunderbird — filename.js
 * -----------------------------------------
 * Mirrors native-host/macos/Sources/AttachClipHost/FilenameSanitizer.swift.
 * Pure functions, no globals leaked.
 *
 * Goals:
 *   1.  Strip anything that would be dangerous on disk or in a paste context.
 *   2.  Preserve the extension when we can.
 *   3.  Resolve same-folder collisions with " (1)", " (2)" ...
 *
 * This file is loaded as part of the background scripts array (see
 * manifest.json). It exposes window.attachclip.filename.
 */

(function (root) {
  "use strict";

  // ---- Reserved Windows names that we strip defensively, even on macOS -----
  const WINDOWS_RESERVED = new Set([
    "CON", "PRN", "AUX", "NUL",
    "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
    "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
  ]);

  // ---- Strip control characters (\x00-\x1F, \x7F) and path separators ------
  function stripDangerous(name) {
    // eslint-disable-next-line no-control-regex
    return String(name)
      .replace(/[\x00-\x1F\x7F]/g, "")
      .replace(/[\\/]/g, "_")
      .replace(/^\.+/, "")
      .replace(/[\s.]+$/, "");
  }

  // ---- Split into stem + extension, preserving the LAST dot ---------------
  function splitExtension(name) {
    const idx = name.lastIndexOf(".");
    if (idx <= 0 || idx === name.length - 1) {
      return { stem: name, ext: "" };
    }
    return { stem: name.slice(0, idx), ext: name.slice(idx) };
  }

  /**
   * sanitize(inputName)
   *   Returns a single clean filename (no directory components).
   */
  function sanitize(inputName) {
    let raw = String(inputName == null ? "" : inputName).normalize("NFC");
    raw = stripDangerous(raw).trim();
    if (!raw) return "attachment";

    const { stem, ext } = splitExtension(raw);
    const cleanStem = stem || "attachment";
    const upperStem = cleanStem.toUpperCase();
    if (WINDOWS_RESERVED.has(upperStem)) {
      return `_${cleanStem}${ext}`;
    }

    // Compose and cap length at 200 chars (filesystem safe; lets systems
    // add suffix like " (1)" without overflowing 255-byte limits).
    const composed = `${cleanStem}${ext}`;
    if (composed.length <= 200) return composed;

    // Truncate the stem, keep extension intact.
    const budget = 200 - ext.length;
    if (budget <= 0) return ext.slice(0, 200);
    return cleanStem.slice(0, budget) + ext;
  }

  /**
   * uniqueName(existingNames, desiredName)
   *   Given a Set/Array of names already used inside the session folder,
   *   returns `desiredName` if free, otherwise `name (1).ext`, `name (2).ext`,
   *   ...
   *
   *   We compare on the FULL filename, not just the stem, because
   *   "report.pdf" vs "report (1).pdf" must coexist cleanly.
   */
  function uniqueName(existingNames, desiredName) {
    const taken = existingNames instanceof Set
      ? existingNames
      : new Set(existingNames || []);
    if (!taken.has(desiredName)) return desiredName;

    const { stem, ext } = splitExtension(desiredName);
    for (let i = 1; i < 10_000; i++) {
      const candidate = `${stem} (${i})${ext}`;
      if (!taken.has(candidate)) return candidate;
    }
    // Pathological fallback: don't loop forever.
    return `${stem}-${Date.now()}${ext}`;
  }

  root.attachclip = root.attachclip || {};
  root.attachclip.filename = { sanitize, uniqueName };
})(typeof self !== "undefined" ? self : this);
