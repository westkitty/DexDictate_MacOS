// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DexDictate_MacOS",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DexDictateKit", targets: ["DexDictateKit"]),
        .executable(name: "DexDictate_MacOS", targets: ["DexDictate"])
    ],
    dependencies: [
        // SwiftWhisper upstream documents very slow Debug builds on `master`.
        // Pin `fast` revision to force -O3 and keep local dictation latency usable in dev.
        .package(url: "https://github.com/exPHAT/SwiftWhisper.git", revision: "deb1cb6a27256c7b01f5d3d2e7dc1dcc330b5d01")
    ],
    targets: [
        .target(
            name: "DexDictateKit",
            dependencies: [.product(name: "SwiftWhisper", package: "SwiftWhisper")],
            path: "Sources/DexDictateKit",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "DexDictate",
            dependencies: ["DexDictateKit"],
            path: "Sources/DexDictate",
            exclude: ["Info.plist", "AppIcon.icns", "DexDictate.entitlements"]
        ),
        .testTarget(
            name: "DexDictateTests",
            dependencies: ["DexDictateKit"]
        ),
        .executableTarget(
            name: "VerificationRunner",
            dependencies: ["DexDictateKit"],
            path: "Sources/VerificationRunner"
        )
    ]
)
