//
// AttachClip for Thunderbird — FilenameSanitizer.swift
// -----------------------------------------------------
// Mirrors extension/src/filename.js. Keep the two in sync.
//
// Goals:
//   1. Defensive: drop control chars + path separators
//   2. Politeness: don't let names break Finder / WeChat / Lark UI
//   3. Predictable: same input -> same output (PII-safe)
//

import Foundation

enum FilenameSanitizer {

    /// Reserved DOS names even though we target macOS, because some
    /// paste-target apps are cross-platform and we want to be safe.
    private static let WINDOWS_RESERVED: Set<String> = [
        "CON", "PRN", "AUX", "NUL",
        "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
    ]

    static func splitExt(_ name: String) -> (stem: String, ext: String) {
        let idx = name.lastIndex(of: ".")
        if let idx = idx, idx > name.startIndex,
           idx != name.index(before: name.endIndex) {
            let stem = String(name[..<idx])
            let ext = String(name[idx...])
            return (stem, ext)
        }
        return (name, "")
    }

    static func sanitize(_ input: String?) -> String {
        let raw = (input ?? "").precomposedStringWithCanonicalMapping
        // Strip control characters (\x00-\x1F, \x7F) and path separators.
        let scrubbed = raw
            .unicodeScalars
            .filter { scalar in
                let v = scalar.value
                if v < 0x20 || v == 0x7F { return false }
                if scalar == "/" || scalar == "\\" { return false }
                return true
            }
            .reduce(into: "") { $0.unicodeScalars.append($1) }
        let trimmed = scrubbed
            .trimmingCharacters(in: CharacterSet(charactersIn: ". \n\r\t"))
        guard !trimmed.isEmpty else { return "attachment" }
        let (stem, ext) = splitExt(trimmed)
        let upperStem = stem.uppercased()
        if WINDOWS_RESERVED.contains(upperStem) {
            return "_\(stem)\(ext)"
        }
        let composed = "\(stem)\(ext)"
        if composed.count <= 200 { return composed }
        // Truncate stem, preserve extension.
        let budget = 200 - ext.count
        if budget <= 0 { return String(ext.prefix(200)) }
        let headIdx = stem.index(stem.startIndex,
                                 offsetBy: min(budget, stem.count))
        return String(stem[..<headIdx]) + ext
    }
}
