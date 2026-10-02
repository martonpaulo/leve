// swift-tools-version:6.2
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
]

let package = Package(
    name: "Leve",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        // Pure logic: it imports only Foundation (AGENTS.md, "Architecture"). It keeps the
        // nonisolated default, so its callers decide isolation.
        .target(
            name: "LeveKit",
            path: "Sources/LeveKit",
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "Leve",
            dependencies: ["LeveKit"],
            path: "Sources/Leve",
            swiftSettings: swiftSettings + [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "LeveKitTests",
            dependencies: ["LeveKit"],
            path: "Tests/LeveKitTests",
            swiftSettings: swiftSettings
        ),
        // The settings owners in the app target, through `@testable import Leve`.
        .testTarget(
            name: "LeveTests",
            dependencies: ["Leve", "LeveKit"],
            path: "Tests/LeveTests",
            swiftSettings: swiftSettings
        ),
    ]
)
