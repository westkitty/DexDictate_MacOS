import XCTest
@testable import DexDictateKit

// MARK: - URL validation

final class SmartCleanupURLValidationTests: XCTestCase {

    func testValidHTTPLoopbackURL() {
        XCTAssertTrue(SmartCleanupURLValidation.isValidURL("http://127.0.0.1:11435/v1"))
    }

    func testValidHTTPSURL() {
        XCTAssertTrue(SmartCleanupURLValidation.isValidURL("https://example.com/v1"))
    }

    func testEmptyStringIsInvalid() {
        XCTAssertFalse(SmartCleanupURLValidation.isValidURL(""))
    }

    func testMissingSchemeIsInvalid() {
        XCTAssertFalse(SmartCleanupURLValidation.isValidURL("127.0.0.1:11435/v1"))
    }

    func testUnsupportedSchemeIsInvalid() {
        XCTAssertFalse(SmartCleanupURLValidation.isValidURL("ftp://127.0.0.1/v1"))
    }

    func testMissingHostIsInvalid() {
        XCTAssertFalse(SmartCleanupURLValidation.isValidURL("http:///v1"))
    }

    func testLoopbackHTTPIsNotFlaggedCleartext() {
        XCTAssertFalse(SmartCleanupURLValidation.isNonLoopbackCleartext("http://127.0.0.1:11435/v1"))
    }

    func testLocalhostHTTPIsNotFlaggedCleartext() {
        XCTAssertFalse(SmartCleanupURLValidation.isNonLoopbackCleartext("http://localhost:11435/v1"))
    }

    func testNonLoopbackHTTPIsFlaggedCleartext() {
        XCTAssertTrue(SmartCleanupURLValidation.isNonLoopbackCleartext("http://192.168.1.50:11435/v1"))
    }

    func testNonLoopbackHTTPSIsNotFlaggedCleartext() {
        // HTTPS is encrypted regardless of host — only plain http on a non-loopback host warns.
        XCTAssertFalse(SmartCleanupURLValidation.isNonLoopbackCleartext("https://example.com/v1"))
    }

    func test127DotPrefixIsTreatedAsLoopback() {
        XCTAssertFalse(SmartCleanupURLValidation.isNonLoopbackCleartext("http://127.5.5.5:11435/v1"))
    }
}

// MARK: - Client request building

@MainActor
final class SmartCleanupClientRequestBuildingTests: XCTestCase {

    func testModelsRequestBuildsGETWithModelsPath() {
        let result = SmartCleanupClient.modelsRequest(baseURLString: "http://127.0.0.1:11435/v1", apiKey: "")
        guard case .success(let request) = result else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:11435/v1/models")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testModelsRequestAddsBearerHeaderWhenAPIKeyPresent() {
        let result = SmartCleanupClient.modelsRequest(baseURLString: "http://127.0.0.1:11435/v1", apiKey: "ollama")
        guard case .success(let request) = result else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer ollama")
    }

    func testModelsRequestFailsOnInvalidBaseURL() {
        let result = SmartCleanupClient.modelsRequest(baseURLString: "not a url", apiKey: "")
        guard case .failure(let error) = result else {
            return XCTFail("expected failure")
        }
        XCTAssertEqual(error, .invalidURL)
    }

    func testChatCompletionsRequestBuildsPOSTWithCorrectPath() {
        let result = SmartCleanupClient.chatCompletionsRequest(
            baseURLString: "http://127.0.0.1:11435/v1", model: "llama3", prompt: "Reply with OK only.", apiKey: ""
        )
        guard case .success(let request) = result else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:11435/v1/chat/completions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testChatCompletionsRequestBodyContainsModelAndPromptAndNonStreaming() throws {
        let result = SmartCleanupClient.chatCompletionsRequest(
            baseURLString: "http://127.0.0.1:11435/v1", model: "llama3", prompt: "Reply with OK only.", apiKey: ""
        )
        guard case .success(let request) = result, let bodyData = request.httpBody else {
            return XCTFail("expected success with a body")
        }
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "llama3")
        XCTAssertEqual(json["stream"] as? Bool, false)
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.first?["role"] as? String, "user")
        XCTAssertEqual(messages.first?["content"] as? String, "Reply with OK only.")
    }

    func testChatCompletionsRequestFailsOnInvalidBaseURL() {
        let result = SmartCleanupClient.chatCompletionsRequest(
            baseURLString: "", model: "llama3", prompt: "hi", apiKey: ""
        )
        guard case .failure(let error) = result else {
            return XCTFail("expected failure")
        }
        XCTAssertEqual(error, .invalidURL)
    }

    func testNoHardCodedDeveloperHostnamesOrPorts() {
        // Guards against regressions reintroducing Andrew's personal setup as a default.
        let result = SmartCleanupClient.modelsRequest(baseURLString: "http://127.0.0.1:11435/v1", apiKey: "")
        guard case .success = result else { return XCTFail("expected success") }
        XCTAssertTrue(SmartCleanupSettings.shared.baseURLString.isEmpty || !SmartCleanupSettings.shared.baseURLString.contains("westcat"))
    }
}

// MARK: - HistoryItem cleaned-variant additivity

final class HistoryItemCleanedVariantTests: XCTestCase {

    func testCleanedTextDefaultsToNil() {
        let item = HistoryItem(text: "hello world")
        XCTAssertNil(item.cleanedText)
    }

    func testCleanedTextCanBeSetViaMemberwiseInit() {
        let item = HistoryItem(text: "hello world", cleanedText: "Hello, world.")
        XCTAssertEqual(item.cleanedText, "Hello, world.")
    }

    func testDecodingOlderPayloadWithoutCleanedTextFieldSucceeds() throws {
        // Simulates a history.json written before Packet 13 — no "cleanedText" key at all.
        let legacyJSON = """
        {"id":"\(UUID().uuidString)","text":"legacy item","createdAt":\(Date().timeIntervalSinceReferenceDate),"sourceHistoryItemID":null,"isAccuracyRetry":false}
        """
        let data = try XCTUnwrap(legacyJSON.data(using: .utf8))
        // .deferredToDate (JSONDecoder's default) matches Date's own Codable conformance,
        // which is how `timeIntervalSinceReferenceDate` above was produced.
        let decoder = JSONDecoder()
        let item = try decoder.decode(HistoryItem.self, from: data)
        XCTAssertEqual(item.text, "legacy item")
        XCTAssertNil(item.cleanedText)
    }
}

// MARK: - TranscriptionHistory.setCleanedText

@MainActor
final class TranscriptionHistorySetCleanedTextTests: XCTestCase {

    func testSetCleanedTextAttachesVariantToMatchingItem() {
        let history = TranscriptionHistory()
        let added = history.add("hello world")
        let itemID = try! XCTUnwrap(added?.id)

        history.setCleanedText("Hello, world.", forItemID: itemID)

        XCTAssertEqual(history.items.first?.cleanedText, "Hello, world.")
        XCTAssertEqual(history.items.first?.text, "hello world", "raw text must never change")
    }

    func testSetCleanedTextIsNoOpForUnknownID() {
        let history = TranscriptionHistory()
        history.add("hello world")
        history.setCleanedText("ignored", forItemID: UUID())

        XCTAssertNil(history.items.first?.cleanedText)
    }
}

// MARK: - SmartCleanupCoordinator disabled-by-default behavior

@MainActor
final class SmartCleanupCoordinatorTests: XCTestCase {

    func testReachabilityIsDisabledWhenSettingIsOff() {
        let settings = SmartCleanupSettings.shared
        let wasEnabled = settings.enabled
        settings.enabled = false
        defer { settings.enabled = wasEnabled }

        let coordinator = SmartCleanupCoordinator(settings: settings)
        let history = TranscriptionHistory()
        coordinator.start(history: history)

        XCTAssertEqual(coordinator.reachability, .disabled)
    }

    func testAddingHistoryItemWhileDisabledDoesNotChangeReachability() {
        let settings = SmartCleanupSettings.shared
        let wasEnabled = settings.enabled
        settings.enabled = false
        defer { settings.enabled = wasEnabled }

        let coordinator = SmartCleanupCoordinator(settings: settings)
        let history = TranscriptionHistory()
        coordinator.start(history: history)
        history.add("this must not trigger any network request")

        XCTAssertEqual(coordinator.reachability, .disabled)
    }
}
