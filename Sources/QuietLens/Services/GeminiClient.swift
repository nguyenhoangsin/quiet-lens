import Foundation

protocol GeminiResponding {
    func answer(image: Data, prompt: String, apiKey: String) async throws -> String
}

struct GeminiClient: GeminiResponding {
    static let model = "gemini-3.5-flash-lite"
    let session: URLSession

    init(session: URLSession? = nil) {
        if let session { self.session = session } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 45
            configuration.timeoutIntervalForResource = 60
            configuration.urlCache = nil
            self.session = URLSession(configuration: configuration)
        }
    }

    func answer(image: Data, prompt: String, apiKey: String) async throws -> String {
        let request = try Self.makeRequest(image: image, prompt: prompt, apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw LensError.emptyResponse }
        if response.statusCode == 429 {
            let delay = Double(response.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 30
            throw LensError.rateLimited(min(300, max(5, delay)))
        }
        guard (200..<300).contains(response.statusCode) else { throw LensError.http(response.statusCode) }
        return try Self.parseResponse(data)
    }

    static func makeRequest(image: Data, prompt: String, apiKey: String) throws -> URLRequest {
        guard !apiKey.isEmpty else { throw LensError.keyRequired }
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LensError.emptyPrompt }
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "contents": [["role": "user", "parts": [
                ["text": prompt],
                ["inline_data": ["mime_type": "image/png", "data": image.base64EncodedString()]],
            ]]],
            "generationConfig": ["maxOutputTokens": 2048],
        ])
        return request
    }

    static func parseResponse(_ data: Data) throws -> String {
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard let candidate = response.candidates?.first else {
            if response.promptFeedback?.blockReason != nil { throw LensError.blockedResponse }
            throw LensError.emptyResponse
        }
        if ["SAFETY", "RECITATION", "PROHIBITED_CONTENT", "BLOCKLIST"].contains(candidate.finishReason ?? "") {
            throw LensError.blockedResponse
        }
        let text = candidate.content?.parts.compactMap { $0.thought == true ? nil : $0.text }
            .joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { throw LensError.emptyResponse }
        return text
    }

    private struct Response: Decodable {
        let candidates: [Candidate]?
        let promptFeedback: Feedback?
        struct Feedback: Decodable { let blockReason: String? }
        struct Candidate: Decodable {
            let content: Content?
            let finishReason: String?
        }
        struct Content: Decodable { let parts: [Part] }
        struct Part: Decodable { let text: String?; let thought: Bool? }
    }
}
