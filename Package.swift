// swift-tools-version:6.4
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
]

let package = Package(
    name: "Leve",
    platforms: [
        .macOS(.v27)
    ],
    dependencies: [
        // The one runtime dependency: automatic updates, the same version as WindowHop (#7).
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0")
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
            dependencies: [
                "LeveKit",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Leve",
            swiftSettings: swiftSettings + [.defaultIsolation(MainActor.self)],
            linkerSettings: [
                // scripts/package-app.sh embeds Sparkle.framework in Contents/Frameworks.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
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
