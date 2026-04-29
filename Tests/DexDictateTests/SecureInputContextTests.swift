import XCTest
@testable import DexDictateKit

final class SecureInputContextTests: XCTestCase {

    // MARK: - False positive prevention

    func testPinSubstringInIdentifierDoesNotFlagOpinionText() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: nil,
            placeholder: nil, label: nil, identifier: "opinionText"
        )
        XCTAssertEqual(SensitiveContextHeuristic.classify(snapshot), .standard)
    }

    func testPinSubstringInIdentifierDoesNotFlagSpinControl() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: nil,
            placeholder: nil, label: nil, identifier: "spinControl"
        )
        XCTAssertEqual(SensitiveContextHeuristic.classify(snapshot), .standard)
    }

    func testTokenSubstringInIdentifierDoesNotFlagTokenField() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: nil,
            placeholder: nil, label: nil, identifier: "tokenField"
        )
        XCTAssertEqual(SensitiveContextHeuristic.classify(snapshot), .standard)
    }

    func testSecretSubstringInIdentifierDoesNotFlagClientSecret() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: nil,
            placeholder: nil, label: nil, identifier: "clientSecret"
        )
        XCTAssertEqual(SensitiveContextHeuristic.classify(snapshot), .standard)
    }

    func testSecretSubstringInIdentifierDoesNotFlagSecretKey() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: nil,
            placeholder: nil, label: nil, identifier: "secretKey"
        )
        XCTAssertEqual(SensitiveContextHeuristic.classify(snapshot), .standard)
    }

    // MARK: - True positive preservation

    func testPasswordInPlaceholderIsSecure() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: nil,
            placeholder: "Enter your password", label: nil, identifier: nil
        )
        XCTAssertEqual(
            SensitiveContextHeuristic.classify(snapshot),
            .sensitive(reason: "Detected likely secure input context (password).")
        )
    }

    func testPinAsStandaloneWordInPlaceholderIsSecure() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: nil,
            placeholder: "Enter your PIN", label: nil, identifier: nil
        )
        XCTAssertEqual(
            SensitiveContextHeuristic.classify(snapshot),
            .sensitive(reason: "Detected likely secure input context (pin).")
        )
    }

    func testTokenAsStandaloneWordInPlaceholderIsSecure() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: nil,
            placeholder: "Enter your API token", label: nil, identifier: nil
        )
        XCTAssertEqual(
            SensitiveContextHeuristic.classify(snapshot),
            .sensitive(reason: "Detected likely secure input context (token).")
        )
    }

    func testSecretAsStandaloneWordInLabelIsSecure() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: nil,
            placeholder: nil, label: "Enter your secret", identifier: nil
        )
        XCTAssertEqual(
            SensitiveContextHeuristic.classify(snapshot),
            .sensitive(reason: "Detected likely secure input context (secret).")
        )
    }

    func testSecureTextFieldSubroleIsAlwaysSecure() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: "AXSecureTextField",
            title: nil, placeholder: nil, label: nil, identifier: "loginField"
        )
        XCTAssertEqual(
            SensitiveContextHeuristic.classify(snapshot),
            .sensitive(reason: "Detected likely secure input context (secure).")
        )
    }

    func testOTPInTitleIsSecure() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: "OTP Code",
            placeholder: nil, label: nil, identifier: nil
        )
        XCTAssertEqual(
            SensitiveContextHeuristic.classify(snapshot),
            .sensitive(reason: "Detected likely secure input context (otp).")
        )
    }

    func testPasscodeInTitleIsSecure() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: "Enter passcode",
            placeholder: nil, label: nil, identifier: nil
        )
        XCTAssertEqual(
            SensitiveContextHeuristic.classify(snapshot),
            .sensitive(reason: "Detected likely secure input context (passcode).")
        )
    }

    func testOneTimeCodeInPlaceholderIsSecure() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: nil,
            placeholder: "one-time code", label: nil, identifier: nil
        )
        XCTAssertEqual(
            SensitiveContextHeuristic.classify(snapshot),
            .sensitive(reason: "Detected likely secure input context (one-time code).")
        )
    }

    func testVerificationCodeInLabelIsSecure() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: nil,
            placeholder: nil, label: "Verification code", identifier: nil
        )
        XCTAssertEqual(
            SensitiveContextHeuristic.classify(snapshot),
            .sensitive(reason: "Detected likely secure input context (verification code).")
        )
    }

    func testTokenWordInPlaceholderFlagsLikelyApiKeyContext() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: nil,
            placeholder: "API key token", label: nil, identifier: nil
        )
        XCTAssertEqual(
            SensitiveContextHeuristic.classify(snapshot),
            .sensitive(reason: "Detected likely secure input context (token).")
        )
    }

    func testTwoFactorAuthTokenInLabelIsSecure() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: nil,
            placeholder: nil, label: "2FA code", identifier: nil
        )
        XCTAssertEqual(
            SensitiveContextHeuristic.classify(snapshot),
            .sensitive(reason: "Detected likely secure input context (2fa).")
        )
    }

    func testPinInLabelAsStandaloneWordIsSecure() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: nil,
            placeholder: nil, label: "PIN", identifier: nil
        )
        XCTAssertEqual(
            SensitiveContextHeuristic.classify(snapshot),
            .sensitive(reason: "Detected likely secure input context (pin).")
        )
    }

    func testStrongTokenInIdentifierStillFlagsSensitiveContext() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: nil,
            placeholder: nil, label: nil, identifier: "payment-passcode-field"
        )
        XCTAssertEqual(
            SensitiveContextHeuristic.classify(snapshot),
            .sensitive(reason: "Detected likely secure input context (passcode).")
        )
    }

    func testStandardFieldIsNotSecure() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField", subrole: nil, title: "Search",
            placeholder: "Search something...", label: nil, identifier: "searchField"
        )
        XCTAssertEqual(SensitiveContextHeuristic.classify(snapshot), .standard)
    }

    func testChatMessageComposerFieldIsNotSecure() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextArea",
            subrole: nil,
            title: "Message",
            placeholder: "Type a message",
            label: "Chat message input",
            identifier: "messageComposer"
        )
        XCTAssertEqual(SensitiveContextHeuristic.classify(snapshot), .standard)
    }

    func testCodeEditorFieldIsNotSecure() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextArea",
            subrole: nil,
            title: "Editor",
            placeholder: nil,
            label: "Source editor",
            identifier: "mainEditorTextView"
        )
        XCTAssertEqual(SensitiveContextHeuristic.classify(snapshot), .standard)
    }
}
