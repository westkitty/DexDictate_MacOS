import Foundation

struct SilverTongueVoice: Decodable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let language: String
    let localPath: String?
}

enum SilverTongueClientError: LocalizedError {
    case invalidResponse
    case badStatusCode(Int)
    case invalidAudioPath(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "SilverTongue returned an invalid response."
        case .badStatusCode(let status):
            return "SilverTongue returned HTTP status \(status)."
        case .invalidAudioPath(let path):
            return "SilverTongue returned an invalid audio path: \(path)"
        }
    }
}

private struct SilverTongueHealthPayload: Decodable {
    let status: String
}

private struct SilverTongueSynthesisRequest: Encodable {
    let text: String
    let voiceId: String
    let speed: Double?
}

private struct SilverTongueSynthesisPayload: Decodable {
    let audioPath: String
}

actor SilverTongueClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "http://127.0.0.1:49152")!, session: URLSession = .shared) {
        precondition(baseURL.host == "127.0.0.1" || baseURL.host == "localhost",
                     "SilverTongueClient must use loopback host only.")
        self.baseURL = baseURL
        self.session = session
    }

    func health() async -> Bool {
        do {
            let payload: SilverTongueHealthPayload = try await request(path: "health", method: "GET")
            return payload.status.lowercased() == "ok"
        } catch {
            return false
        }
    }

    func listVoices() async throws -> [SilverTongueVoice] {
        try await request(path: "voices", method: "GET")
    }

    func synthesize(text: String, voiceID: String, speed: Double) async throws -> URL {
        let body = SilverTongueSynthesisRequest(
            text: text,
            voiceId: voiceID,
            speed: speed
        )
        let payload: SilverTongueSynthesisPayload = try await request(path: "synthesize", method: "POST", body: body, timeoutInterval: 120)
        guard !payload.audioPath.isEmpty else {
            throw SilverTongueClientError.invalidAudioPath(payload.audioPath)
        }
        return URL(fileURLWithPath: payload.audioPath)
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body?,
        timeoutInterval: TimeInterval = 10
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SilverTongueClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SilverTongueClientError.badStatusCode(httpResponse.statusCode)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func request<Response: Decodable>(
        path: String,
        method: String
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SilverTongueClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SilverTongueClientError.badStatusCode(httpResponse.statusCode)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}
