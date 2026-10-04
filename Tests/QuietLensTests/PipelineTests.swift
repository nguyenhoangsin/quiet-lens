import AppKit
import Testing
@testable import QuietLens

@MainActor
struct PipelineTests {
    @Test func testStoppedRunCannotPublishLateAnswer() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let client = DelayedClient()
        let model = fixture.model(client: client)
        model.askNow()
        await waitUntil { client.started }
        #expect(client.started)
        model.stop()
        client.complete("Late answer")
        await Task.yield()
        await Task.yield()
        #expect(model.answer == "")
        #expect(!(model.isBusy))
        #expect(!(model.isMonitoring))
    }

    @Test func testSavingPromptCancelsPendingAnswerAndNextRequestUsesNewPrompt() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let client = DelayedClient()
        let model = fixture.model(client: client)
        model.askNow()
        await waitUntil { client.started }
        let previousSettings = model.settings
        try model.savePrompt("New prompt")
        #expect(model.settings == previousSettings)
        #expect(model.prompt == "New prompt")
        client.complete("Old answer")
        await Task.yield()
        model.askNow()
        await waitUntil { client.prompts.count == 2 }
        #expect(client.prompts.last == "New prompt")
        client.complete("New answer")
        await waitUntil { model.answer == "New answer" }
        #expect(model.answer == "New answer")
    }

    @Test func testMissingPermissionDoesNotCaptureOrSend() async {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let capture = FakeCapture()
        capture.hasPermission = false
        let client = DelayedClient()
        let model = fixture.model(client: client, capture: capture)
        model.askNow()
        await Task.yield()
        #expect(capture.captureCount == 0)
        #expect(!(client.started))
        #expect(model.errorMessage != nil)
        #expect(!(model.isBusy))
    }

    @Test func testAutoDoesNotResendSameImageAfterPauseAndResume() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let client = ImmediateClient()
        let model = fixture.model(client: client, mode: .auto)
        model.startMonitoring()
        await waitUntil { !model.answer.isEmpty }
        #expect(model.answer == "Answer")
        model.stop()
        model.startMonitoring()
        try await Task.sleep(nanoseconds: 1_200_000_000)
        #expect(client.count == 1)
        model.stop()
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

@MainActor
private final class Fixture {
    let name = "QuietLensPipelineTests.\(UUID())"
    var defaults: UserDefaults { UserDefaults(suiteName: name)! }
    func cleanUp() { defaults.removePersistentDomain(forName: name) }
    func model(client: GeminiResponding, capture: FakeCapture? = nil, mode: CaptureMode = .manual) -> QuietLensViewModel {
        var settings = LensSettings()
        settings.mode = mode
        settings.captureInterval = 0.3
        settings.debounce = 0.5
        settings.region = ScreenRegion(displayID: 1, displayName: "Test", displaySize: CGSize(width: 100, height: 100),
                                       rect: CGRect(x: 0, y: 0, width: 80, height: 80))
        try! ConfigurationStore(defaults: defaults).save(settings)
        return QuietLensViewModel(capture: capture ?? FakeCapture(), client: client, keys: FakeKeys(),
                                  prompts: PromptManager(defaults: defaults), configuration: ConfigurationStore(defaults: defaults))
    }
}

@MainActor
private final class FakeCapture: ScreenCapturing {
    var hasPermission = true
    var captureCount = 0
    func prepare(for region: ScreenRegion) async throws {}
    func capture(_ region: ScreenRegion) async throws -> CGImage {
        captureCount += 1
        let context = CGContext(data: nil, width: 80, height: 80, bitsPerComponent: 8, bytesPerRow: 80 * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        return context.makeImage()!
    }
    func reset() {}
}

private struct FakeKeys: APIKeyManaging {
    func read() throws -> String? { "fake-key" }
    func save(_ key: String) throws {}
    func delete() throws {}
}

@MainActor
private final class ImmediateClient: GeminiResponding {
    var count = 0
    nonisolated func answer(image: Data, prompt: String, apiKey: String) async throws -> String {
        await record()
    }
    private func record() -> String { count += 1; return "Answer" }
}

@MainActor
private final class DelayedClient: GeminiResponding {
    var started = false
    var prompts: [String] = []
    private var continuation: CheckedContinuation<String, Never>?
    nonisolated func answer(image: Data, prompt: String, apiKey: String) async throws -> String {
        await waitForAnswer(prompt: prompt)
    }
    private func waitForAnswer(prompt: String) async -> String {
        prompts.append(prompt)
        started = true
        return await withCheckedContinuation { continuation = $0 }
    }
    func complete(_ answer: String) { continuation?.resume(returning: answer); continuation = nil }
}
