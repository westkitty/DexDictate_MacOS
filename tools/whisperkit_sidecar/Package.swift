// swift-tools-version: 6.0
//
// ISOLATED BENCHMARK-ONLY PACKAGE. This package is deliberately *separate* from
// the production DexDictate `Package.swift` at the repo root. It is never built
// by `build.sh`, never part of the app/release, and pulls WhisperKit only into
// this throwaway benchmark executable. Keeping it out of the production target
// means WhisperKit cannot accidentally end up in the shipped, notarized app.
import PackageDescription

let package = Package(
    name: "whisperkit-sidecar",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "whisperkit-transcribe",
            dependencies: [.product(name: "WhisperKit", package: "WhisperKit")],
            path: "Sources/whisperkit-transcribe",
            // Benchmark CLI: use the Swift 5 language mode so the single-threaded
            // top-level driver can call the non-Sendable WhisperKit class without
            // Swift 6 strict-concurrency ceremony. This is a throwaway tool, not
            // app code.
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
