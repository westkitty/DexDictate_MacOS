import AVFoundation
import XCTest
import DexDictateObjCSupport

/// Verifies the Objective-C exception bridge converts the `NSException` that
/// `AVAudioNode.installTap`/`removeTap` can raise into a recoverable Swift error
/// instead of aborting the process.
///
/// The double-install case is the exact failure class behind crash
/// 48CE6BEE-99AE-41EC-8D5B-EA70BE5D4932: AVFoundation raises an uncatchable
/// `NSException` which, without the bridge, calls `abort()`. Using an
/// `AVAudioPlayerNode` keeps the test free of any microphone hardware.
///
/// NOTE: the `AVAudioEngine` must stay alive for the duration of every tap call —
/// AVFoundation raises `NSException` ("NULL != engine") if the node's engine has
/// been released. Each test holds the engine via `withExtendedLifetime`.
final class AudioTapInstallerTests: XCTestCase {
    private func makeConnectedPlayerNode() throws -> (AVAudioEngine, AVAudioPlayerNode, AVAudioFormat) {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2))
        engine.connect(player, to: engine.mainMixerNode, format: format)
        return (engine, player, format)
    }

    func testFirstInstallSucceeds() throws {
        let (engine, player, format) = try makeConnectedPlayerNode()
        try withExtendedLifetime(engine) {
            defer { try? DDAudioTapInstaller.removeTap(on: player, bus: 0) }
            XCTAssertNoThrow(
                try DDAudioTapInstaller.installTap(
                    on: player, bus: 0, bufferSize: 4096, format: format, block: { _, _ in }
                )
            )
        }
    }

    func testDoubleInstallThrowsInsteadOfCrashing() throws {
        let (engine, player, format) = try makeConnectedPlayerNode()
        try withExtendedLifetime(engine) {
            defer { try? DDAudioTapInstaller.removeTap(on: player, bus: 0) }

            try DDAudioTapInstaller.installTap(
                on: player, bus: 0, bufferSize: 4096, format: format, block: { _, _ in }
            )

            // The second install raises an NSException inside AVFoundation. The bridge
            // must surface it as a thrown NSError — reaching this assertion at all proves
            // the process did not abort.
            XCTAssertThrowsError(
                try DDAudioTapInstaller.installTap(
                    on: player, bus: 0, bufferSize: 4096, format: format, block: { _, _ in }
                )
            ) { error in
                let nsError = error as NSError
                XCTAssertEqual(nsError.domain, DDAudioTapInstallerErrorDomain)
                XCTAssertEqual(nsError.code, DDAudioTapInstallerErrorCode.installFailed.rawValue)
                XCTAssertNotNil(nsError.userInfo[DDAudioTapInstallerExceptionNameKey])
                XCTAssertFalse(nsError.localizedDescription.isEmpty)
            }
        }
    }

    func testRemoveTapAfterInstallSucceeds() throws {
        let (engine, player, format) = try makeConnectedPlayerNode()
        try withExtendedLifetime(engine) {
            try DDAudioTapInstaller.installTap(
                on: player, bus: 0, bufferSize: 4096, format: format, block: { _, _ in }
            )
            XCTAssertNoThrow(try DDAudioTapInstaller.removeTap(on: player, bus: 0))
        }
    }

    func testRemoveTapWhenNoneInstalledDoesNotCrash() throws {
        let (engine, player, _) = try makeConnectedPlayerNode()
        withExtendedLifetime(engine) {
            // Removing a non-existent tap must not crash, whether AVFoundation treats it
            // as a no-op or raises an exception (which the bridge would catch).
            XCTAssertNoThrow(try? DDAudioTapInstaller.removeTap(on: player, bus: 0))
        }
    }
}
