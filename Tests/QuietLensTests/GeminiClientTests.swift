import Testing
import Foundation
@testable import QuietLens

struct GeminiClientTests {
    @Test func testRequestSendsPromptAndImageWithoutKeyInURL() throws {
        let png = Data([1, 2, 3])
        let request = try GeminiClient.makeRequest(image: png, prompt: "Read this", apiKey: "test-secret")
        #expect(request.httpMethod == "POST")
        #expect(request.url?.host == "generativelanguage.googleapis.com")
        #expect(request.url!.path.contains("gemini-3.5-flash-lite"))
        #expect(request.url?.query == nil)
        #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "test-secret")
        let body = try #require(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        let contents = body["contents"] as! [[String: Any]]
        let parts = contents[0]["parts"] as! [[String: Any]]
        #expect(parts[0]["text"] as? String == "Read this")
        let image = parts[1]["inline_data"] as! [String: String]
        #expect(image["mime_type"] == "image/png")
        #expect(image["data"] == png.base64EncodedString())
        #expect(!(String(data: request.httpBody!, encoding: .utf8)!.contains("test-secret")))
    }

    @Test func testParserOmitsThinkingAndJoinsVisibleParts() throws {
        let data = Data(#"{"candidates":[{"content":{"parts":[{"text":"private thought","thought":true},{"text":"B"},{"text":"Short explanation."}]},"finishReason":"STOP"}]}"#.utf8)
        #expect(try GeminiClient.parseResponse(data) == "B\nShort explanation.")
    }

    @Test func testBlockedAndEmptyResponsesAreNotShownAsAnswers() {
        for json in [#"{"promptFeedback":{"blockReason":"SAFETY"}}"#,
                     #"{"candidates":[{"finishReason":"SAFETY"}]}"#,
                     #"{"candidates":[{"content":{"parts":[{"text":"  "}]}}]}"#] {
            #expect(throws: (any Error).self) { try GeminiClient.parseResponse(Data(json.utf8)) }
        }
    }

    @Test func testRateLimitHonorsRetryAfter() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RateLimitProtocol.self]
        let client = GeminiClient(session: URLSession(configuration: configuration))
        do {
            _ = try await client.answer(image: Data([1]), prompt: "Read", apiKey: "fake")
            Issue.record("Expected a rate-limit error")
        } catch LensError.rateLimited(let delay) { #expect(delay == 42) }
    }
}

private final class RateLimitProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil,
                                       headerFields: ["Retry-After": "42"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
