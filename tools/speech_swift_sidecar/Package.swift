// swift-tools-version: 6.0
//
// ISOLATED BENCHMARK-ONLY PACKAGE. Deliberately separate from the production
// DexDictate `Package.swift` at the repo root. Never built by `build.sh`, never
// part of the app/release. It pulls `soniqo/speech-swift`'s `ParakeetStreamingASR`
// only into this throwaway benchmark CLI so streaming ASR / partial-hypothesis /
// end-of-utterance behavior can be measured without touching production.
//
// NOTE ON macOS FLOOR: soniqo/speech-swift requires `.macOS(15)`. DexDictate's
// production floor is macOS 14. This benchmark package therefore declares
// `.macOS(.v15)` ONLY for the isolated tool; it does NOT change the app's floor.
// Production integration of speech-swift would require raising the floor, gating
// it as an optional macOS 15+ backend, or rejecting it.
import PackageDescription

let package = Package(
    name: "speech-swift-benchmark",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/soniqo/speech-swift", exact: "0.0.21")
    ],
    targets: [
        .executableTarget(
            name: "speech-swift-benchmark",
            dependencies: [
                .product(name: "ParakeetStreamingASR", package: "speech-swift"),
                .product(name: "AudioCommon", package: "speech-swift"),
            ],
            path: "Sources/speech-swift-benchmark",
            // Single-threaded benchmark CLI calling a non-Sendable model class;
            // use Swift 5 language mode to avoid Swift 6 strict-concurrency churn.
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
