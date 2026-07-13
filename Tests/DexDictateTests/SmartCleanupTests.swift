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

        XCTAssertEqual(coordinator.reachability, .notEnabled)
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

        XCTAssertEqual(coordinator.reachability, .notEnabled)
    }

    func testEnablingAfterStartTransitionsThroughUnknownAndTriggersRefresh() {
        let settings = SmartCleanupSettings.shared
        let wasEnabled = settings.enabled
        let wasURL = settings.baseURLString
        settings.enabled = false
        settings.baseURLString = ""
        defer {
            settings.enabled = wasEnabled
            settings.baseURLString = wasURL
        }

        let coordinator = SmartCleanupCoordinator(settings: settings)
        let history = TranscriptionHistory()
        coordinator.start(history: history)
        XCTAssertEqual(coordinator.reachability, .notEnabled)

        settings.enabled = true
        coordinator.handleEnabledSettingChanged()
        // Immediately after flipping the setting, reachability must not still read
        // .notEnabled — it must become .unknown right away (a check kicks off in the
        // background), even though the empty base URL means that check will resolve to
        // .serviceUnavailable shortly after.
        XCTAssertEqual(coordinator.reachability, .unknown)
    }

    func testDisablingAfterEnabledResetsToNotEnabled() {
        let settings = SmartCleanupSettings.shared
        let wasEnabled = settings.enabled
        settings.enabled = true
        defer { settings.enabled = wasEnabled }

        let coordinator = SmartCleanupCoordinator(settings: settings)
        let history = TranscriptionHistory()
        coordinator.start(history: history)

        settings.enabled = false
        coordinator.handleEnabledSettingChanged()
        XCTAssertEqual(coordinator.reachability, .notEnabled)
    }

    func testRefreshReachabilityWithNoBaseURLReportsServiceUnavailable() async {
        let settings = SmartCleanupSettings.shared
        let wasEnabled = settings.enabled
        let wasURL = settings.baseURLString
        settings.enabled = true
        settings.baseURLString = ""
        defer {
            settings.enabled = wasEnabled
            settings.baseURLString = wasURL
        }

        let coordinator = SmartCleanupCoordinator(settings: settings)
        await coordinator.refreshReachability()

        guard case .serviceUnavailable = coordinator.reachability else {
            return XCTFail("expected .serviceUnavailable with an empty base URL, got \(coordinator.reachability)")
        }
    }

    func testRefreshReachabilityWhileDisabledStaysNotEnabled() async {
        let settings = SmartCleanupSettings.shared
        let wasEnabled = settings.enabled
        settings.enabled = false
        defer { settings.enabled = wasEnabled }

        let coordinator = SmartCleanupCoordinator(settings: settings)
        await coordinator.refreshReachability()

        XCTAssertEqual(coordinator.reachability, .notEnabled)
    }
}

// MARK: - SmartCleanupReachability label/detail mapping

final class SmartCleanupReachabilityLabelTests: XCTestCase {

    func testNotEnabledLabel() {
        XCTAssertEqual(SmartCleanupReachability.notEnabled.statusLabel, "Not enabled")
        XCTAssertNil(SmartCleanupReachability.notEnabled.detail)
    }

    func testReadyLabel() {
        XCTAssertEqual(SmartCleanupReachability.ready.statusLabel, "Ready")
        XCTAssertNil(SmartCleanupReachability.ready.detail)
    }

    func testServiceUnavailableCarriesReasonAsDetail() {
        let state = SmartCleanupReachability.serviceUnavailable(reason: "No server address configured.")
        XCTAssertEqual(state.statusLabel, "Service unavailable")
        XCTAssertEqual(state.detail, "No server address configured.")
    }

    func testModelNotInstalledCarriesReasonAsDetail() {
        let state = SmartCleanupReachability.modelNotInstalled(reason: "Model 'llama3' not found.")
        XCTAssertEqual(state.statusLabel, "Model not installed")
        XCTAssertEqual(state.detail, "Model 'llama3' not found.")
    }

    func testAuthenticationRequiredHasNoDetail() {
        XCTAssertEqual(SmartCleanupReachability.authenticationRequired.statusLabel, "Authentication required")
        XCTAssertNil(SmartCleanupReachability.authenticationRequired.detail)
    }

    func testLastRequestFailedCarriesReasonAsDetail() {
        let state = SmartCleanupReachability.lastRequestFailed(reason: "Connection reset.")
        XCTAssertEqual(state.statusLabel, "Last request failed")
        XCTAssertEqual(state.detail, "Connection reset.")
    }
}

// MARK: - Mocked-backend coordinator behavior

/// Intercepts requests made through `URLSession.shared` (what `SmartCleanupClient` uses
/// internally) so the coordinator's request/response mapping can be tested against a
/// canned backend without a real server — `SmartCleanupClient`'s network calls take a
/// `session` parameter, but the coordinator itself always calls them with the default
/// `.shared`, so intercepting at the `URLProtocol` layer is the only seam that doesn't
/// require changing production call sites.
private final class SmartCleanupMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseProvider: (@Sendable (URLRequest) -> (Int, Data))?
    /// Optional artificial per-request delay (seconds), keyed off the request itself — lets a
    /// test deterministically force which of two concurrent requests resolves first, instead
    /// of hoping real scheduling happens to land a particular way. `nil`/0 means "no delay,"
    /// which is every existing test's behavior.
    nonisolated(unsafe) static var responseDelayProvider: (@Sendable (URLRequest) -> TimeInterval)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let provider = Self.responseProvider, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        let (status, data) = provider(request)
        let delay = Self.responseDelayProvider?(request) ?? 0

        func deliver() {
            let response = HTTPURLResponse(
                url: url, statusCode: status, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }

        guard delay > 0 else { return deliver() }
        DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: deliver)
    }

    override func stopLoading() {}
}

/// Free function (not MainActor-isolated) — `responseProvider` runs on the URL loading
/// system's background thread, so anything it captures must be callable from there.
private func smartCleanupMockModelsResponseJSON(ids: [String]) -> Data {
    let payload: [String: Any] = ["data": ids.map { ["id": $0] }]
    return try! JSONSerialization.data(withJSONObject: payload)
}

@MainActor
final class SmartCleanupCoordinatorMockedBackendTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(SmartCleanupMockURLProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(SmartCleanupMockURLProtocol.self)
        SmartCleanupMockURLProtocol.responseProvider = nil
        SmartCleanupMockURLProtocol.responseDelayProvider = nil
        super.tearDown()
    }

    func testRefreshReachabilityReportsReadyWhenConfiguredModelIsPresent() async {
        let settings = SmartCleanupSettings.shared
        let wasEnabled = settings.enabled
        let wasURL = settings.baseURLString
        let wasModel = settings.model
        settings.enabled = true
        settings.baseURLString = "http://127.0.0.1:59991/v1"
        settings.model = "llama3"
        defer {
            settings.enabled = wasEnabled
            settings.baseURLString = wasURL
            settings.model = wasModel
        }

        SmartCleanupMockURLProtocol.responseProvider = { _ in
            (200, smartCleanupMockModelsResponseJSON(ids: ["llama3", "mistral"]))
        }

        let coordinator = SmartCleanupCoordinator(settings: settings)
        await coordinator.refreshReachability()

        XCTAssertEqual(coordinator.reachability, .ready)
    }

    func testRefreshReachabilityReportsModelNotInstalledWhenConfiguredModelIsMissing() async {
        let settings = SmartCleanupSettings.shared
        let wasEnabled = settings.enabled
        let wasURL = settings.baseURLString
        let wasModel = settings.model
        settings.enabled = true
        settings.baseURLString = "http://127.0.0.1:59992/v1"
        settings.model = "llama3"
        defer {
            settings.enabled = wasEnabled
            settings.baseURLString = wasURL
            settings.model = wasModel
        }

        SmartCleanupMockURLProtocol.responseProvider = { _ in
            (200, smartCleanupMockModelsResponseJSON(ids: ["mistral", "phi3"]))
        }

        let coordinator = SmartCleanupCoordinator(settings: settings)
        await coordinator.refreshReachability()

        guard case .modelNotInstalled(let reason) = coordinator.reachability else {
            return XCTFail("expected .modelNotInstalled, got \(coordinator.reachability)")
        }
        XCTAssertTrue(reason.contains("llama3"))
    }

    func testRefreshReachabilityReportsAuthenticationRequiredOn401() async {
        let settings = SmartCleanupSettings.shared
        let wasEnabled = settings.enabled
        let wasURL = settings.baseURLString
        settings.enabled = true
        settings.baseURLString = "http://127.0.0.1:59993/v1"
        defer {
            settings.enabled = wasEnabled
            settings.baseURLString = wasURL
        }

        SmartCleanupMockURLProtocol.responseProvider = { _ in (401, Data()) }

        let coordinator = SmartCleanupCoordinator(settings: settings)
        await coordinator.refreshReachability()

        XCTAssertEqual(coordinator.reachability, .authenticationRequired)
    }

    func testSuccessfulCleanupAttachesCleanedTextAndReportsReady() async throws {
        let settings = SmartCleanupSettings.shared
        let wasEnabled = settings.enabled
        let wasURL = settings.baseURLString
        settings.enabled = true
        settings.baseURLString = "http://127.0.0.1:59994/v1"
        defer {
            settings.enabled = wasEnabled
            settings.baseURLString = wasURL
        }

        SmartCleanupMockURLProtocol.responseProvider = { _ in
            let payload: [String: Any] = [
                "choices": [["message": ["role": "assistant", "content": "Hello, world."]]]
            ]
            return (200, try! JSONSerialization.data(withJSONObject: payload))
        }

        let coordinator = SmartCleanupCoordinator(settings: settings)
        let history = TranscriptionHistory()
        coordinator.start(history: history)
        let added = history.add("hello world")
        let itemID = try XCTUnwrap(added?.id)

        // The coordinator's own history-change subscription drives cleanup asynchronously;
        // poll briefly rather than assuming a fixed delay is always enough on a loaded CI box.
        // Note: start(history:) also fires its own background refreshReachability() against
        // this same mock — since the mock always returns the chat-completion shape (not the
        // /models list shape), that connection-test request fails to decode and settles on
        // .serviceUnavailable independently of the cleanup call. Only the cleanup path (this
        // test's actual subject) sets .ready on success, so poll on cleanedText — the durable
        // signal that the real cleanup attempt finished — rather than on reachability.
        for _ in 0..<50 where history.items.first(where: { $0.id == itemID })?.cleanedText == nil {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(history.items.first(where: { $0.id == itemID })?.cleanedText, "Hello, world.")
    }

    func testFailedCleanupReportsLastRequestFailedAndLeavesRawTextStanding() async throws {
        let settings = SmartCleanupSettings.shared
        let wasEnabled = settings.enabled
        let wasURL = settings.baseURLString
        settings.enabled = true
        settings.baseURLString = "http://127.0.0.1:59995/v1"
        defer {
            settings.enabled = wasEnabled
            settings.baseURLString = wasURL
        }

        SmartCleanupMockURLProtocol.responseProvider = { _ in (500, Data()) }

        let coordinator = SmartCleanupCoordinator(settings: settings)
        let history = TranscriptionHistory()
        coordinator.start(history: history)
        let added = history.add("this stays raw")
        let itemID = try XCTUnwrap(added?.id)

        // start(history:) also kicks off its own refreshReachability() in the background
        // (against the same mocked 500 response), which would settle on .serviceUnavailable
        // before the item-triggered cleanup attempt overwrites it with .lastRequestFailed —
        // so poll specifically for the final state this test cares about, not just "changed".
        for _ in 0..<75 {
            if case .lastRequestFailed = coordinator.reachability { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        guard case .lastRequestFailed = coordinator.reachability else {
            return XCTFail("expected .lastRequestFailed, got \(coordinator.reachability)")
        }
        XCTAssertNil(history.items.first(where: { $0.id == itemID })?.cleanedText)
        XCTAssertEqual(history.items.first(where: { $0.id == itemID })?.text, "this stays raw")
    }

    /// Regression test for a genuine production race: `start(history:)` kicks off its own
    /// background `refreshReachability()` (hits `/models`), and a real cleanup attempt
    /// triggered by a new history item (hits `/chat/completions`) runs concurrently — with no
    /// ordering guarantee between them. Before the generation-guard fix in
    /// `SmartCleanupCoordinator`, whichever network response happened to arrive *last* won,
    /// so a slow, stale auto-refresh could silently overwrite a real cleanup attempt's more
    /// specific `.lastRequestFailed`. `testFailedCleanupReportsLastRequestFailedAndLeavesRawTextStanding`
    /// above only reproduced this ~40% of the time, since it depended on real scheduling
    /// happening to land the "wrong" way under full-suite contention. This test instead
    /// *forces* that exact adversarial ordering deterministically via `responseDelayProvider`,
    /// so it fails every single run without the fix and passes every single run with it.
    func testStaleAutoRefreshCannotOverwriteNewerCleanupResult() async throws {
        let settings = SmartCleanupSettings.shared
        let wasEnabled = settings.enabled
        let wasURL = settings.baseURLString
        settings.enabled = true
        settings.baseURLString = "http://127.0.0.1:59996/v1"
        defer {
            settings.enabled = wasEnabled
            settings.baseURLString = wasURL
        }

        SmartCleanupMockURLProtocol.responseProvider = { _ in (500, Data()) }
        // The /models request (start()'s auto-refresh) is deliberately delayed well past the
        // /chat/completions request (the real cleanup attempt) so the auto-refresh — despite
        // starting first — is guaranteed to *resolve* last every time.
        SmartCleanupMockURLProtocol.responseDelayProvider = { request in
            request.url?.lastPathComponent == "models" ? 0.3 : 0
        }

        let coordinator = SmartCleanupCoordinator(settings: settings)
        let history = TranscriptionHistory()
        coordinator.start(history: history)
        let added = history.add("this stays raw despite the stale auto-refresh")
        let itemID = try XCTUnwrap(added?.id)

        // The undelayed cleanup attempt should resolve almost immediately.
        for _ in 0..<50 {
            if case .lastRequestFailed = coordinator.reachability { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        guard case .lastRequestFailed = coordinator.reachability else {
            return XCTFail("expected the fast cleanup attempt to report .lastRequestFailed first, got \(coordinator.reachability)")
        }

        // Wait well past the artificial /models delay so the stale auto-refresh has
        // definitely resolved too. Before the fix, this is exactly where it would silently
        // overwrite .lastRequestFailed with .serviceUnavailable.
        try await Task.sleep(nanoseconds: 500_000_000)

        guard case .lastRequestFailed = coordinator.reachability else {
            return XCTFail("stale auto-refresh overwrote a newer, real cleanup result — got \(coordinator.reachability)")
        }
        XCTAssertNil(history.items.first(where: { $0.id == itemID })?.cleanedText)
    }
}
