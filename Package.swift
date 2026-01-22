// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DexDictate_MacOS",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "DexDictate_MacOS", targets: ["DexDictate"])],
    dependencies: [
        // Using KeyboardShortcuts or implementing manual tap? We use manual tap for Mouse events.
    ],
    targets: [
        .executableTarget(
            name: "DexDictate",
            dependencies: [],
            path: "Sources/DexDictate",
            resources: [.process("Resources")]
        )
    ]
)
