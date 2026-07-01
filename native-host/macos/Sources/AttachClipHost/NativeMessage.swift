//
// AttachClip for Thunderbird — NativeMessage.swift
// -------------------------------------------------
// Encoding/decoding helpers for the wire protocol documented in
// docs/native-messaging.md. We deliberately keep these as helpers
// rather than a Codable struct because the protocol evolved organically
// and we're still free to add optional fields without breaking schema.
//

import Foundation

struct NativeRequest {
    enum Kind: String {
        case ping
        case begin_session
        case begin_file
        case write_chunk
        case end_file
        case commit_clipboard
        case clear_cache
        case unknown
    }

    let kind: Kind
    let nonce: String?
    let payload: [String: Any]

    static func parse(_ data: Data) -> NativeRequest? {
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any],
              let type = dict["type"] as? String else { return nil }
        return NativeRequest(
            kind: Kind(rawValue: type) ?? .unknown,
            nonce: dict["nonce"] as? String,
            payload: dict
        )
    }
}

enum NativeResponse {
    static func ok(nonce: String?, _ extra: [String: Any] = [:]) -> Data {
        var dict: [String: Any] = ["ok": true]
        dict.merge(extra) { _, new in new }
        if let n = nonce { dict["nonce"] = n }
        return serialize(dict)
    }

    static func error(nonce: String?, reason: String, message: String,
                      detail: String? = nil) -> Data {
        var errBody: [String: Any] = [
            "reason": reason,
            "message": message,
        ]
        if let d = detail { errBody["detail"] = d }
        var dict: [String: Any] = [
            "ok": false,
            "error": errBody,
        ]
        if let n = nonce { dict["nonce"] = n }
        return serialize(dict)
    }

    private static func serialize(_ dict: [String: Any]) -> Data {
        do {
            return try JSONSerialization.data(
                withJSONObject: dict,
                options: [.sortedKeys]
            )
        } catch {
            // Fallback to an empty object — the extension will treat it as
            // a malformed response and time out cleanly.
            return Data("{}".utf8)
        }
    }
}
