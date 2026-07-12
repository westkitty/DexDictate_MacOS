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
        .package(url: "https://github.com/exPHAT/SwiftWhisper.git", revision: "deb1cb6a27256c7b01f5d3d2e7dc1dcc330b5d01"),
        // Real, native Swift/CoreML backends for the Parakeet (fast local) and Nemotron
        // (live streaming) transcription providers. Apache 2.0. Both models are downloaded
        // on demand (gated behind explicit user action), never bundled or fetched by default.
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.15.4"),
        // Real, first-party Swift/ONNX Runtime backend for the Moonshine (command mode)
        // transcription provider. MIT. Model weights downloaded on demand, gated behind
        // explicit user action.
        .package(url: "https://github.com/moonshine-ai/moonshine-swift.git", from: "0.0.65")
    ],
    targets: [
        // Objective-C shim that wraps AVAudioNode tap operations in @try/@catch so
        // the NSException they can raise becomes a recoverable Swift error instead
        // of aborting the process. Pure Swift targets cannot catch ObjC exceptions.
        .target(
            name: "DexDictateObjCSupport",
            path: "Sources/DexDictateObjCSupport",
            linkerSettings: [.linkedFramework("AVFoundation")]
        ),
        .target(
            name: "DexDictateKit",
            dependencies: [
                .product(name: "SwiftWhisper", package: "SwiftWhisper"),
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "MoonshineVoice", package: "moonshine-swift"),
                "DexDictateObjCSupport"
            ],
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
            dependencies: [
                "DexDictateKit",
                "DexDictateObjCSupport",
                .product(name: "FluidAudio", package: "FluidAudio")
            ]
        ),
        .executableTarget(
            name: "VerificationRunner",
            dependencies: ["DexDictateKit"],
            path: "Sources/VerificationRunner"
        )
    ]
)
