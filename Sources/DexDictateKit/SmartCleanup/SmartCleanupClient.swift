import Foundation

/// Plain `URLSession` client for an OpenAI-compatible `/v1` endpoint (e.g. Ollama's
/// compatibility layer). No agent framework, no tool-calling, no streaming — a single
/// non-streaming `/v1/chat/completions` request per call, exactly as this packet requires.
///
/// Request-building is split into pure, synchronous functions (`modelsRequest`,
/// `chatCompletionsRequest`) so they can be unit tested without a live server.
public enum SmartCleanupClientError: Error, Equatable, LocalizedError {
    case invalidURL
    case invalidResponse
    case http(Int)
    case decoding
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid or missing base URL."
        case .invalidResponse: return "The server sent an unexpected response."
        case .http(let code): return "Server returned HTTP \(code)."
        case .decoding: return "Could not parse the server's response."
        case .network(let message): return message
        }
    }
}

public struct SmartCleanupModelsResult: Equatable {
    public let modelIDs: [String]
}

public struct SmartCleanupInferenceResult: Equatable {
    public let reply: String
    public let roundTripMS: Int
}

public enum SmartCleanupClient {

    // MARK: - Request building (pure, testable)

    public static func modelsRequest(baseURLString: String, apiKey: String) -> Result<URLRequest, SmartCleanupClientError> {
        guard SmartCleanupURLValidation.isValidURL(baseURLString), let base = URL(string: baseURLString) else {
            return .failure(.invalidURL)
        }
        var request = URLRequest(url: base.appendingPathComponent("models"))
        request.httpMethod = "GET"
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        return .success(request)
    }

    public static func chatCompletionsRequest(
        baseURLString: String,
        model: String,
        prompt: String,
        apiKey: String
    ) -> Result<URLRequest, SmartCleanupClientError> {
        guard SmartCleanupURLValidation.isValidURL(baseURLString), let base = URL(string: baseURLString) else {
            return .failure(.invalidURL)
        }
        let url = base.appendingPathComponent("chat").appendingPathComponent("completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "stream": false
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return .success(request)
    }

    // MARK: - Network calls

    public static func testConnection(
        baseURLString: String,
        apiKey: String,
        timeout: TimeInterval = 8,
        session: URLSession = .shared
    ) async -> Result<SmartCleanupModelsResult, SmartCleanupClientError> {
        guard case .success(var request) = modelsRequest(baseURLString: baseURLString, apiKey: apiKey) else {
            return .failure(.invalidURL)
        }
        request.timeoutInterval = timeout
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure(.invalidResponse) }
            guard (200...299).contains(http.statusCode) else { return .failure(.http(http.statusCode)) }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let modelsArray = json["data"] as? [[String: Any]] else {
                return .failure(.decoding)
            }
            let ids = modelsArray.compactMap { $0["id"] as? String }
            return .success(SmartCleanupModelsResult(modelIDs: ids))
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    public static func testInference(
        baseURLString: String,
        model: String,
        apiKey: String,
        timeout: TimeInterval = 8,
        session: URLSession = .shared
    ) async -> Result<SmartCleanupInferenceResult, SmartCleanupClientError> {
        guard case .success(var request) = chatCompletionsRequest(
            baseURLString: baseURLString, model: model, prompt: "Reply with OK only.", apiKey: apiKey
        ) else {
            return .failure(.invalidURL)
        }
        request.timeoutInterval = timeout
        let start = Date()
        do {
            let (data, response) = try await session.data(for: request)
            let elapsedMS = Int(Date().timeIntervalSince(start) * 1000)
            guard let http = response as? HTTPURLResponse else { return .failure(.invalidResponse) }
            guard (200...299).contains(http.statusCode) else { return .failure(.http(http.statusCode)) }
            guard let reply = extractReply(from: data) else { return .failure(.decoding) }
            return .success(SmartCleanupInferenceResult(reply: reply, roundTripMS: elapsedMS))
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    /// Post-processing only — called after the raw transcript is already committed and
    /// delivered. Never on the insertion path, never blocking, never retried more than once
    /// (the coordinator itself enforces "at most one attempt" per item).
    public static func cleanup(
        text: String,
        baseURLString: String,
        model: String,
        apiKey: String,
        timeout: TimeInterval = 8,
        session: URLSession = .shared
    ) async -> Result<String, SmartCleanupClientError> {
        let prompt = """
        Clean up and lightly format the following dictated text. Fix obvious punctuation \
        and capitalization. Do not change the meaning or add commentary. Reply with ONLY \
        the cleaned text, nothing else.

        \(text)
        """
        guard case .success(var request) = chatCompletionsRequest(
            baseURLString: baseURLString, model: model, prompt: prompt, apiKey: apiKey
        ) else {
            return .failure(.invalidURL)
        }
        request.timeoutInterval = timeout
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return .failure(.invalidResponse)
            }
            guard let reply = extractReply(from: data), !reply.isEmpty else { return .failure(.decoding) }
            return .success(reply)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    // MARK: - Response parsing

    private static func extractReply(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return nil
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
