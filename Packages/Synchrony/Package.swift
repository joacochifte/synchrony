// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Synchrony",
    defaultLocalization: "es",
    platforms: [
        .iOS(.v17),
        // Not a real deployment target — the app only ships on iOS. This
        // just gives `swift test` a modern enough macOS minimum to run
        // locally and in CI, since that always builds for the host.
        .macOS(.v14)
    ],
    products: [
        .library(name: "SynchronyCore", targets: ["SynchronyCore"]),
        .library(name: "SynchronyTransport", targets: ["SynchronyTransport"]),
        .library(name: "SynchronyPersistence", targets: ["SynchronyPersistence"]),
        .library(name: "SynchronyUI", targets: ["SynchronyUI"])
    ],
    targets: [
        .target(
            name: "SynchronyCore",
            resources: [.process("Resources/prompts.json")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "SynchronyTransport",
            dependencies: ["SynchronyCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "SynchronyPersistence",
            dependencies: ["SynchronyCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "SynchronyUI",
            dependencies: ["SynchronyCore", "SynchronyTransport", "SynchronyPersistence"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SynchronyCoreTests",
            dependencies: ["SynchronyCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SynchronyTransportTests",
            dependencies: ["SynchronyTransport"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SynchronyPersistenceTests",
            dependencies: ["SynchronyPersistence"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SynchronyUITests",
            dependencies: ["SynchronyUI"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
