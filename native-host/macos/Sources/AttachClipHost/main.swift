//
// AttachClip for Thunderbird — main.swift
// -----------------------------------------
// Stdio-based JSON dispatcher. Reads 4-byte little-endian lengths from
// stdin, decodes each message, dispatches to the matching handler, and
// writes the JSON response back length-prefixed on stdout.
//
// We never print anything that isn't an explicit `os_log` line, and
// `os_log` itself goes to the macOS unified log so the user can verify
// behaviour without it leaking into the JSON channel.
//

import Foundation
import os

private let log = OSLog(subsystem: "com.attachclip.host", category: "main")

// MARK: - Native Messaging framing

func readExact(_ n: Int) -> Data? {
    var buf = Data(count: n)
    var read = 0
    while read < n {
        let got = buf.withUnsafeMutableBytes { ptr -> Int in
            guard let base = ptr.baseAddress else { return 0 }
            return fread(base.advanced(by: read), 1, n - read, stdin)
        }
        if got <= 0 { return nil } // EOF before we had n bytes
        read += got
    }
    return buf
}

func readFrame() -> Data? {
    guard let lengthBuf = readExact(4) else { return nil }
    let length = lengthBuf.withUnsafeBytes { $0.load(as: UInt32.self) }
    // Sanity-cap incoming frame at 16 MB so a buggy / hostile sender
    // can't fill memory; the spec only requires <1MB responses but
    // requests can be larger (chunked writes).
    if length == 0 || length > 16 * 1024 * 1024 {
        os_log("Refusing frame of length %{public}u", log: log, type: .error, length)
        return nil
    }
    return readExact(Int(length))
}

func writeFrame(_ data: Data) {
    var len = UInt32(data.count).littleEndian
    var lenBytes = Data(bytes: &len, count: 4)
    lenBytes.append(data)
    _ = lenBytes.withUnsafeBytes { ptr in
        fwrite(ptr.baseAddress, 1, lenBytes.count, stdout)
    }
    fflush(stdout)
}

func emit(_ response: [String: Any]) {
    do {
        let data = try JSONSerialization.data(
            withJSONObject: response, options: [])
        writeFrame(data)
    } catch {
        os_log("emit JSON failed: %{public}@", log: log, type: .error,
               String(describing: error))
    }
}

func errorResponse(nonce: String?, reason: String, message: String,
                   detail: String? = nil) -> [String: Any] {
    var errBody: [String: Any] = [
        "reason": reason,
        "message": message,
    ]
    if let d = detail { errBody["detail"] = d }
    var r: [String: Any] = [
        "ok": false,
        "error": errBody,
    ]
    if let n = nonce { r["nonce"] = n }
    return r
}

func okResponse(nonce: String?, payload: [String: Any] = [:]) -> [String: Any] {
    var r: [String: Any] = ["ok": true]
    r.merge(payload) { _, new in new }
    if let n = nonce { r["nonce"] = n }
    return r
}

// MARK: - Session state

private let cache = CacheStore()

func handleBeginFile(_ msg: [String: Any]) -> [String: Any] {
    guard let sessionId = msg["sessionId"] as? String,
          let fileId = msg["fileId"] as? String,
          let rawName = msg["suggestedName"] as? String else {
        return errorResponse(nonce: msg["nonce"] as? String,
                             reason: "BAD_REQUEST",
                             message: "begin_file missing required fields")
    }
    let contentType = (msg["contentType"] as? String) ?? "application/octet-stream"
    let size = (msg["size"] as? Int) ?? 0
    do {
        let cleanName = FilenameSanitizer.sanitize(rawName)
        let finalName = cache.reserveName(sessionId: sessionId,
                                          baseName: cleanName)
        try cache.openFile(sessionId: sessionId,
                           fileId: fileId,
                           finalName: finalName,
                           contentType: contentType,
                           expectedSize: size)
        return okResponse(nonce: msg["nonce"] as? String,
                           payload: ["fileId": fileId,
                                     "finalName": finalName,
                                     "path": cache.absolutePath(sessionId: sessionId,
                                                               fileId: fileId).path])
    } catch {
        return errorResponse(nonce: msg["nonce"] as? String,
                             reason: "IO_ERROR",
                             message: "could not create cache file",
                             detail: String(describing: error))
    }
}

// MARK: - Dispatch

func dispatch(_ msg: [String: Any]) -> [String: Any] {
    guard let type = msg["type"] as? String else {
        return errorResponse(nonce: msg["nonce"] as? String,
                             reason: "BAD_REQUEST",
                             message: "missing type")
    }
    let nonce = msg["nonce"] as? String

    switch type {
    case "ping":
        let v = (msg["v"] as? Int) ?? 0
        return okResponse(nonce: nonce, payload: ["pong": true,
                                                  "type": "pong",
                                                  "v": v,
                                                  "build": "0.1.0-alpha.1"])

    case "begin_session":
        do {
            let info = try cache.beginSession()
            return okResponse(nonce: nonce, payload: [
                "type": "session_started",
                "sessionId": info.sessionId,
                "sessionDir": info.dir.path,
                "expiresAt": ISO8601DateFormatter().string(from: info.expiresAt),
            ])
        } catch {
            return errorResponse(nonce: nonce, reason: "SESSION_FAILED",
                                 message: "could not begin session",
                                 detail: String(describing: error))
        }

    case "begin_file":
        return handleBeginFile(msg)

    case "write_chunk":
        guard let sessionId = msg["sessionId"] as? String,
              let fileId = msg["fileId"] as? String,
              let dataB64 = msg["data"] as? String else {
            return errorResponse(nonce: nonce, reason: "BAD_REQUEST",
                                 message: "write_chunk missing fields")
        }
        guard let chunk = Data(base64Encoded: dataB64) else {
            return errorResponse(nonce: nonce, reason: "BAD_ENCODING",
                                 message: "chunk is not valid base64")
        }
        do {
            let written = try cache.writeChunk(sessionId: sessionId,
                                               fileId: fileId,
                                               chunk: chunk)
            return okResponse(nonce: nonce, payload: [
                "type": "chunk_written",
                "fileId": fileId,
                "bytesWritten": written,
            ])
        } catch {
            return errorResponse(nonce: nonce, reason: "IO_ERROR",
                                 message: "chunk write failed",
                                 detail: String(describing: error))
        }

    case "end_file":
        let sessionId = (msg["sessionId"] as? String) ?? ""
        let fileId = (msg["fileId"] as? String) ?? ""
        let abort = (msg["abort"] as? Bool) ?? false
        if abort {
            cache.abortFile(sessionId: sessionId, fileId: fileId)
            return okResponse(nonce: nonce, payload: ["type": "file_aborted",
                                                      "fileId": fileId])
        }
        do {
            let info = try cache.closeFile(sessionId: sessionId, fileId: fileId)
            return okResponse(nonce: nonce, payload: [
                "type": "file_closed",
                "fileId": fileId,
                "path": info.path,
                "size": info.size,
            ])
        } catch {
            return errorResponse(nonce: nonce, reason: "IO_ERROR",
                                 message: "could not close file",
                                 detail: String(describing: error))
        }

    case "commit_clipboard":
        guard let sessionId = msg["sessionId"] as? String else {
            return errorResponse(nonce: nonce, reason: "BAD_REQUEST",
                                 message: "commit_clipboard missing sessionId")
        }
        let urls = cache.urlsForSession(sessionId: sessionId)
        if urls.isEmpty {
            return errorResponse(nonce: nonce, reason: "CLIPBOARD_WRITE_FAILED",
                                 message: "no files committed in session")
        }
        do {
            try ClipboardWriter.commit(urls: urls)
            return okResponse(nonce: nonce, payload: [
                "type": "commit_ok",
                "count": urls.count,
                "urls": urls.map { $0.path },
            ])
        } catch {
            return errorResponse(nonce: nonce, reason: "CLIPBOARD_WRITE_FAILED",
                                 message: "NSPasteboard rejected the payload",
                                 detail: String(describing: error))
        }

    case "clear_cache":
        let hours = (msg["olderThanHours"] as? Int) ?? 72
        let result = cache.clearStale(olderThanHours: hours)
        return okResponse(nonce: nonce, payload: [
            "type": "cache_cleared",
            "filesRemoved": result.files,
            "bytesReclaimed": result.bytes,
        ])

    default:
        return errorResponse(nonce: nonce, reason: "UNKNOWN_TYPE",
                             message: "unrecognized message type",
                             detail: type)
    }
}

// MARK: - Entry point

func mainLoop() {
    while true {
        guard let frame = readFrame() else {
            os_log("stdin EOF / framing error; exiting cleanly", log: log, type: .info)
            return
        }
        guard let obj = try? JSONSerialization.jsonObject(with: frame),
              let msg = obj as? [String: Any] else {
            os_log("dropped unparseable frame of %{public}d bytes",
                   log: log, type: .error, frame.count)
            emit(errorResponse(nonce: nil, reason: "BAD_JSON",
                               message: "frame did not parse as JSON object"))
            continue
        }
        let response = dispatch(msg)
        emit(response)
    }
}

// `main.swift` is the script entry; just invoke the loop.
// swift requires top-level code (or @main); we use the script form.
mainLoop()
