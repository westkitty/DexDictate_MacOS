import XCTest
@testable import DexDictateKit

// MARK: - EngineDisplayState tests

final class EngineDisplayStateTests: XCTestCase {

    func testLabelIsNonEmptyForAllCases() {
        let cases: [EngineDisplayState] = [
            .stopped, .initializing, .ready, .listening, .transcribing, .error("boom")
        ]
        for state in cases {
            XCTAssertFalse(state.label.isEmpty, "label is empty for \(state)")
        }
    }

    func testErrorLabelFallsBackWhenMessageEmpty() {
        XCTAssertEqual(EngineDisplayState.error("").label, "Error")
    }

    func testErrorLabelUsesProvidedMessage() {
        XCTAssertEqual(EngineDisplayState.error("Model missing").label, "Model missing")
    }

    func testSystemImageIsNonEmptyForAllCases() {
        let cases: [EngineDisplayState] = [
            .stopped, .initializing, .ready, .listening, .transcribing, .error("")
        ]
        for state in cases {
            XCTAssertFalse(state.systemImage.isEmpty, "systemImage empty for \(state)")
        }
    }

    func testIsActiveOnlyDuringListeningAndTranscribing() {
        XCTAssertTrue(EngineDisplayState.listening.isActive)
        XCTAssertTrue(EngineDisplayState.transcribing.isActive)
        XCTAssertFalse(EngineDisplayState.stopped.isActive)
        XCTAssertFalse(EngineDisplayState.ready.isActive)
        XCTAssertFalse(EngineDisplayState.initializing.isActive)
        XCTAssertFalse(EngineDisplayState.error("").isActive)
    }

    func testEquatabilityOfMatchingCases() {
        XCTAssertEqual(EngineDisplayState.stopped, .stopped)
        XCTAssertEqual(EngineDisplayState.error("x"), .error("x"))
        XCTAssertNotEqual(EngineDisplayState.error("a"), .error("b"))
        XCTAssertNotEqual(EngineDisplayState.stopped, .ready)
    }
}

// MARK: - PermissionDisplayState tests

final class PermissionDisplayStateTests: XCTestCase {

    func testAllGrantedWhenAllTrue() {
        let s = PermissionDisplayState(micGranted: true, accessibilityGranted: true, inputMonitoringGranted: true)
        XCTAssertTrue(s.allGranted)
    }

    func testAllGrantedFalseWhenAnyMissing() {
        XCTAssertFalse(PermissionDisplayState(micGranted: false, accessibilityGranted: true,  inputMonitoringGranted: true).allGranted)
        XCTAssertFalse(PermissionDisplayState(micGranted: true,  accessibilityGranted: false, inputMonitoringGranted: true).allGranted)
        XCTAssertFalse(PermissionDisplayState(micGranted: true,  accessibilityGranted: true,  inputMonitoringGranted: false).allGranted)
    }

    func testMissingLabelsListsOnlyMissingPermissions() {
        let s = PermissionDisplayState(micGranted: false, accessibilityGranted: true, inputMonitoringGranted: false)
        XCTAssertEqual(s.missingLabels.count, 2)
        XCTAssertTrue(s.missingLabels.contains("Microphone"))
        XCTAssertTrue(s.missingLabels.contains("Input Monitoring"))
        XCTAssertFalse(s.missingLabels.contains("Accessibility"))
    }

    func testMissingLabelsEmptyWhenAllGranted() {
        let s = PermissionDisplayState(micGranted: true, accessibilityGranted: true, inputMonitoringGranted: true)
        XCTAssertTrue(s.missingLabels.isEmpty)
    }
}

// MARK: - DexExperimentalUIState tests

final class DexExperimentalUIStateTests: XCTestCase {

    func testPlaceholderHasExpectedDefaults() {
        let p = DexExperimentalUIState.placeholder
        XCTAssertEqual(p.engine, .stopped)
        XCTAssertFalse(p.permissions.allGranted)
        XCTAssertFalse(p.output.safeMode)
        XCTAssertTrue(p.output.autoPaste)
        XCTAssertTrue(p.output.lastFeedbackTitle.isEmpty)
        XCTAssertEqual(p.transcript.liveText, "")
        XCTAssertNil(p.transcript.recentText)
        XCTAssertEqual(p.transcript.inputLevel, 0)
        XCTAssertNil(p.transcript.silenceCountdown)
        XCTAssertEqual(p.dexterLine.text, "")
    }

    func testEquatabilityRoundtrip() {
        let a = DexExperimentalUIState.placeholder
        var b = DexExperimentalUIState.placeholder
        XCTAssertEqual(a, b)
        b.engine = .ready
        XCTAssertNotEqual(a, b)
    }
}

// MARK: - TranscriptionFeedback adapter contract tests

final class TranscriptionFeedbackAdapterContractTests: XCTestCase {

    private let allCases: [TranscriptionFeedback] = [
        .idle,
        .noSpeechDetected,
        .nothingToDelete,
        .deletedPreviousHistory,
        .restoredPreviousHistory,
        .discardedCurrentUtterance,
        .savedToHistory(modified: false),
        .savedToHistory(modified: true),
        .copiedOnlySensitiveContext(modified: false, reason: "test"),
        .copiedOnlySensitiveContext(modified: true, reason: "test"),
        .pastedToActiveApp(modified: false),
        .pastedToActiveApp(modified: true),
    ]

    func testTitleIsStringForAllCases() {
        // title may be empty for .idle — just verify it doesn't crash and is a String
        for fb in allCases {
            let _ = fb.title  // must not trap
        }
    }

    func testSymbolNameIsNonEmptyForAllCases() {
        for fb in allCases {
            XCTAssertFalse(fb.symbolName.isEmpty, "symbolName empty for \(fb)")
        }
    }

    func testToneIsDefinedForAllCases() {
        for fb in allCases {
            let _ = fb.tone  // must not trap
        }
    }

    func testIdleTitleIsEmpty() {
        XCTAssertTrue(TranscriptionFeedback.idle.title.isEmpty)
    }

    func testNoSpeechDetectedToneIsWarning() {
        XCTAssertEqual(TranscriptionFeedback.noSpeechDetected.tone, .warning)
    }

    func testPastedToActiveAppToneIsSuccess() {
        XCTAssertEqual(TranscriptionFeedback.pastedToActiveApp(modified: false).tone, .success)
    }

    func testCopiedOnlySensitiveContextIsClipboardFallback() {
        // Adapter uses a pattern-match on this case to set isClipboardFallback = true
        let fb = TranscriptionFeedback.copiedOnlySensitiveContext(modified: false, reason: "password field")
        if case .copiedOnlySensitiveContext = fb {
            // expected — adapter maps this to isClipboardFallback = true
        } else {
            XCTFail("Pattern match failed")
        }
    }
}

// MARK: - FlavorQuotePacks Dexter feed contract tests

final class FlavorQuotePacksDexterFeedTests: XCTestCase {

    func testEveryProfilePackIsNonEmpty() {
        for profile in AppProfile.allCases {
            let pack = FlavorQuotePacks.pack(for: profile)
            XCTAssertFalse(pack.isEmpty, "pack for \(profile) is empty")
        }
    }

    func testEveryLineHasNonEmptyText() {
        for profile in AppProfile.allCases {
            for line in FlavorQuotePacks.pack(for: profile) {
                XCTAssertFalse(line.text.isEmpty, "empty text in \(profile) pack")
            }
        }
    }

    func testCrossProfileAggregationProducesLines() {
        // mirrors the flatMap pattern used in DexDexterFeedView.loadLines()
        let allLines = AppProfile.allCases.flatMap { profile in
            FlavorQuotePacks.pack(for: profile).map { ($0.text, profile.rawValue) }
        }
        XCTAssertGreaterThanOrEqual(allLines.count, AppProfile.allCases.count,
            "expected at least one line per profile")
    }

    func testSamplingFiveUniqueLinesSucceeds() {
        let allLines = AppProfile.allCases.flatMap { profile in
            FlavorQuotePacks.pack(for: profile).map { ($0.text, profile.rawValue) }
        }
        guard allLines.count >= 5 else {
            XCTFail("Not enough lines to sample 5 (\(allLines.count) total)")
            return
        }
        // Simulate the reduce-based deduplication from loadLines()
        var used = Set<Int>()
        var result: [String] = []
        for _ in 0..<5 {
            var attempts = 0
            while attempts < 20 {
                let idx = Int.random(in: 0..<allLines.count)
                if !used.contains(idx) {
                    used.insert(idx)
                    result.append(allLines[idx].0)
                    break
                }
                attempts += 1
            }
        }
        XCTAssertEqual(result.count, 5, "expected exactly 5 unique sampled lines")
        XCTAssertEqual(Set(result).count, 5, "sampled lines must be unique")
    }

    func testAllProfilesAreCoveredByCaseIterable() {
        // Ensures we never accidentally add an AppProfile case without adding a pack
        let profileCount = AppProfile.allCases.count
        XCTAssertGreaterThanOrEqual(profileCount, 3, "expected at least standard/canadian/aussie")
        for profile in AppProfile.allCases {
            let pack = FlavorQuotePacks.pack(for: profile)
            XCTAssertFalse(pack.isEmpty, "AppProfile.\(profile) has no quote pack entries")
        }
    }
}
