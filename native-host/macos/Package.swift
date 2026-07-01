// swift-tools-version:5.7
//
// AttachClip for Thunderbird — Package.swift
// -------------------------------------------
// macOS native messaging host. Targets macOS 12+ (Apple Silicon and Intel)
// so we can rely on the modern NSPasteboard.writeObjects API.
//
// Build:
//   cd native-host/macos
//   swift build -c release
//
// The resulting binary lands at:
//   .build/release/attachclip-host
// install.sh copies it to /usr/local/bin (or ~/.local/bin if not root).

import PackageDescription

let package = Package(
    name: "AttachClipHost",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "attachclip-host", targets: ["AttachClipHost"])
    ],
    targets: [
        .executableTarget(
            name: "AttachClipHost",
            path: "Sources/AttachClipHost"
        )
    ]
)
