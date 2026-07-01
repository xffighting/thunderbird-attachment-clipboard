//
// AttachClip for Thunderbird — ClipboardWriter.swift
// ---------------------------------------------------
// The only place we talk to NSPasteboard. Wraps the write so the rest
// of the codebase can stay pure-Foundation and testable without a GUI
// session.
//
// We deliberately use `writeObjects([fileURLs])` rather than
// `declareTypes(_:owner:) + setString(_:forType:)`. The former lands as
// actual file references so Apps (Finder, WeChat, Lark, etc.) see file
// URLs and behave identically to drag-and-drop.
//

import AppKit
import os

private let log = OSLog(subsystem: "com.attachclip.host", category: "clipboard")

enum ClipboardWriter {

    /// Replace the contents of NSPasteboard.general with the given file URLs.
    ///
    /// Throws on failure so the caller can map the error back to the
    /// `CLIPBOARD_WRITE_FAILED` reason code the extension expects.
    static func commit(urls: [URL]) throws {
        guard !urls.isEmpty else {
            throw NSError(domain: "AttachClip", code: 1,
                          userInfo: [NSLocalizedDescriptionKey:
                                     "commit called with zero URLs"])
        }
        // Validate every URL still exists on disk.  A session can outlive
        // its files (e.g. user wiped the cache) — we want a clean error,
        // not a silently broken pasteboard.
        let live = urls.filter { fmFileExists($0) }
        guard live.count == urls.count else {
            throw NSError(domain: "AttachClip", code: 2,
                          userInfo: [NSLocalizedDescriptionKey:
                            "Some session files were missing from disk."])
        }

        let pb = NSPasteboard.general
        pb.clearContents()
        let ok = pb.writeObjects(live as [NSURL])
        if !ok {
            os_log("NSPasteboard.writeObjects returned false", log: log,
                   type: .error)
            throw NSError(domain: "AttachClip", code: 3,
                          userInfo: [NSLocalizedDescriptionKey:
                                     "NSPasteboard refused to accept the URLs"])
        }
        os_log("Committed %{public}d file URL(s) to pasteboard",
               log: log, type: .info, live.count)
    }

    private static func fmFileExists(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path,
                                                     isDirectory: &isDir)
        return exists && !isDir.boolValue
    }
}
