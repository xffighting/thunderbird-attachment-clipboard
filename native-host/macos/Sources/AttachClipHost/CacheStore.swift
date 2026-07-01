//
// AttachClip for Thunderbird — CacheStore.swift
// ----------------------------------------------
// Owns the on-disk session directory layout and TTL cleanup.
//
// Layout (default root `~/Library/Caches/AttachClip/`):
//
//   AttachClip/
//     sessions/
//       <sessionId>/
//         meta.json         - creation time, label (optional)
//         <final name>      - one file per attachment
//
// We deliberately keep metadata in a small JSON sidecar per session so
// clearing can be done with a simple mtime + JSON read. We never write
// attachment contents anywhere except inside the session dir; no
// telemetry, no temp copies elsewhere.
//

import Foundation
import os

private let log = OSLog(subsystem: "com.attachclip.host", category: "cache")

struct CacheSessionInfo {
    let sessionId: String
    let dir: URL
    let expiresAt: Date
}

struct ClosedFileInfo {
    let path: String
    let size: Int
}

struct ClearResult {
    let files: Int
    let bytes: Int64
}

final class CacheStore {

    private let fm = FileManager.default
    private let root: URL
    private var sessionDirs: [String: URL] = [:]

    init(rootOverride: URL? = nil) {
        if let r = rootOverride {
            self.root = r
        } else {
            let caches = try? fm.url(for: .cachesDirectory,
                                     in: .userDomainMask,
                                     appropriateFor: nil,
                                     create: true)
            let base = caches ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Caches", isDirectory: true)
            self.root = base.appendingPathComponent("AttachClip",
                                                    isDirectory: true)
        }
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        try? fm.createDirectory(at: sessionsRoot(),
                                withIntermediateDirectories: true)
    }

    // MARK: - Public surface

    func sessionsRoot() -> URL {
        root.appendingPathComponent("sessions", isDirectory: true)
    }

    /// Create a new session directory. sessionId is generated; expires 72h
    /// from `Date()` by default but the helper may extend it later.
    func beginSession(ttlHours: Int = 72) throws -> CacheSessionInfo {
        let id = "s_\(UUID().uuidString)"
        let dir = sessionsRoot().appendingPathComponent(id, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let expires = Date().addingTimeInterval(TimeInterval(ttlHours * 3600))
        let meta: [String: Any] = [
            "sessionId": id,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "expiresAt": ISO8601DateFormatter().string(from: expires),
            "version": 1,
        ]
        let metaURL = dir.appendingPathComponent("meta.json")
        let data = try JSONSerialization.data(
            withJSONObject: meta, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: metaURL, options: .atomic)
        sessionDirs[id] = dir
        os_log("Session %{public}@ created", log: log, type: .info, id)
        return CacheSessionInfo(sessionId: id, dir: dir, expiresAt: expires)
    }

    /// Reserve a non-colliding filename within a session directory.
    /// Mirrors the JS `uniqueName` in extension/src/filename.js.
    func reserveName(sessionId: String, baseName: String) -> String {
        let dir = sessionDirs[sessionId] ?? absoluteSessionDir(sessionId)
        var name = baseName
        var i = 1
        while fm.fileExists(atPath: dir.appendingPathComponent(name).path) {
            let (stem, ext) = FilenameSanitizer.splitExt(name)
            name = "\(stem) (\(i))\(ext)"
            i += 1
            if i > 10_000 {
                // Pathological fallback; pairs with the JS side.
                return "\(stem)-\(Int(Date().timeIntervalSince1970))\(ext)"
            }
        }
        return name
    }

    func openFile(sessionId: String, fileId: String, finalName: String,
                  contentType: String, expectedSize: Int) throws {
        let dir = absoluteSessionDir(sessionId)
        let url = dir.appendingPathComponent(finalName)
        // Empty-out (or create) the file before we start appending.
        // `FileHandle(forWritingTo:)` requires the file to exist; creating it
        // here means subsequent `writeChunk` calls can `seekToEnd` and append
        // safely from any order.
        if !fm.createFile(atPath: url.path,
                          contents: nil,
                          attributes: [.posixPermissions: 0o600]) {
            throw NSError(domain: "AttachClip", code: 20,
                          userInfo: [NSLocalizedDescriptionKey:
                            "could not create cache file at \(url.path)"])
        }
        // Sanity-touch the file via FileHandle so any FS error surfaces here.
        let probe = try FileHandle(forWritingTo: url)
        try? probe.close()
        // Store URL in the per-file dict so writeChunk can append.
        openHandles[handleKey(sessionId: sessionId, fileId: fileId)] = url
        pendingMeta[handleKey(sessionId: sessionId, fileId: fileId)] = [
            "fileId": fileId,
            "suggestedName": finalName,
            "contentType": contentType,
            "expectedSize": expectedSize,
        ]
    }

    func writeChunk(sessionId: String, fileId: String, chunk: Data) throws -> Int {
        let key = handleKey(sessionId: sessionId, fileId: fileId)
        guard let url = openHandles[key] else {
            throw NSError(domain: "AttachClip", code: 10,
                          userInfo: [NSLocalizedDescriptionKey:
                            "no open file for fileId=\(fileId)"])
        }
        // Append-mode handle, recreate each time to avoid stale handles.
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path,
                          contents: nil,
                          attributes: [.posixPermissions: 0o600])
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: chunk)
        return chunk.count
    }

    func closeFile(sessionId: String, fileId: String) throws -> ClosedFileInfo {
        let key = handleKey(sessionId: sessionId, fileId: fileId)
        guard let url = openHandles.removeValue(forKey: key) else {
            throw NSError(domain: "AttachClip", code: 11,
                          userInfo: [NSLocalizedDescriptionKey:
                            "no open file for fileId=\(fileId)"])
        }
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir),
              !isDir.boolValue else {
            throw NSError(domain: "AttachClip", code: 12,
                          userInfo: [NSLocalizedDescriptionKey:
                            "missing file on close: \(url.path)"])
        }
        let attrs = try fm.attributesOfItem(atPath: url.path)
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0

        // Update session meta so the file count is queryable later.
        updateSessionMeta(sessionId: sessionId) { meta in
            var files = meta["files"] as? [[String: Any]] ?? []
            files.append([
                "path": url.path,
                "size": size,
                "closedAt": ISO8601DateFormatter().string(from: Date()),
                "contentType":
                    (pendingMeta[key]?["contentType"] as? String) ?? "application/octet-stream",
                "suggestedName":
                    (pendingMeta[key]?["suggestedName"] as? String) ?? url.lastPathComponent,
            ])
            meta["files"] = files
        }
        pendingMeta.removeValue(forKey: key)
        return ClosedFileInfo(path: url.path, size: size)
    }

    func abortFile(sessionId: String, fileId: String) {
        let key = handleKey(sessionId: sessionId, fileId: fileId)
        if let url = openHandles.removeValue(forKey: key) {
            try? fm.removeItem(at: url)
        }
        pendingMeta.removeValue(forKey: key)
    }

    func urlsForSession(sessionId: String) -> [URL] {
        let dir = absoluteSessionDir(sessionId)
        guard let entries = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]) else { return [] }
        return entries
            .filter { $0.lastPathComponent != "meta.json" }
            .filter { url in
                var isDir: ObjCBool = false
                fm.fileExists(atPath: url.path, isDirectory: &isDir)
                return !isDir.boolValue
            }
    }

    /// Delete sessions whose meta indicates they are older than `olderThanHours`.
    /// Returns aggregate counts.
    func clearStale(olderThanHours hours: Int) -> ClearResult {
        let cutoff = Date().addingTimeInterval(
            -TimeInterval(hours) * 3600)
        let root = sessionsRoot()
        guard let entries = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]) else {
            return ClearResult(files: 0, bytes: 0)
        }
        var files = 0
        var bytes: Int64 = 0
        for entry in entries {
            let metaURL = entry.appendingPathComponent("meta.json")
            var mtime: Date = Date.distantPast
            if let attr = try? fm.attributesOfItem(atPath: metaURL.path),
               let d = attr[.modificationDate] as? Date {
                mtime = d
            } else if let attr = try? entry.resourceValues(
                forKeys: [.contentModificationDateKey]).contentModificationDate {
                mtime = attr
            }
            if mtime > cutoff { continue }
            // Count + remove.
            if let contents = try? fm.contentsOfDirectory(
                at: entry,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]) {
                for c in contents {
                    if let attr = try? c.resourceValues(forKeys: [.fileSizeKey])
                        .fileSize,
                       attr > 0 {
                        bytes += Int64(attr)
                    }
                    try? fm.removeItem(at: c)
                    files += 1
                }
            }
            try? fm.removeItem(at: entry)
        }
        os_log("Cleared %{public}d stale files (%{public}lld bytes)",
               log: log, type: .info, files, bytes)
        return ClearResult(files: files, bytes: bytes)
    }

    // MARK: - Lookups & update helpers

    func absolutePath(sessionId: String, fileId: String) -> URL {
        let dir = absoluteSessionDir(sessionId)
        // fileId is an internal key; the URL is keyed off the file's
        // final name (recorded in begin_file). For this alpha we expose
        // the session dir when the file isn't currently open.
        let key = handleKey(sessionId: sessionId, fileId: fileId)
        if let url = openHandles[key] { return url }
        return dir
    }

    // MARK: - Internal

    private var openHandles: [String: URL] = [:]
    private var pendingMeta: [String: [String: Any]] = [:]

    private func handleKey(sessionId: String, fileId: String) -> String {
        return "\(sessionId)::\(fileId)"
    }

    private func absoluteSessionDir(_ sessionId: String) -> URL {
        if let d = sessionDirs[sessionId] { return d }
        let d = sessionsRoot().appendingPathComponent(sessionId,
                                                      isDirectory: true)
        sessionDirs[sessionId] = d
        return d
    }

    private func updateSessionMeta(sessionId: String,
                                   update: (inout [String: Any]) -> Void) {
        let dir = absoluteSessionDir(sessionId)
        let url = dir.appendingPathComponent("meta.json")
        var meta: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let parsed = try? JSONSerialization.jsonObject(with: data)
            as? [String: Any] {
            meta = parsed
        }
        update(&meta)
        if let data = try? JSONSerialization.data(
            withJSONObject: meta,
            options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
