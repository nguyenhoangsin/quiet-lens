import AppKit
import Combine

@MainActor
final class QuietLensViewModel: ObservableObject {
    @Published private(set) var settings: LensSettings
    @Published private(set) var prompt: String
    @Published private(set) var hasAPIKey = false
    @Published private(set) var isMonitoring = false
    @Published private(set) var isBusy = false
    @Published private(set) var isSelecting = false
    @Published private(set) var status = "Ready when you are"
    @Published private(set) var errorMessage: String?
    @Published private(set) var answer = ""
    @Published private(set) var answeredAt: Date?
    @Published private(set) var requestCount = 0
    @Published var section: Section = .lens
    @Published var showsOverlay = true

    enum Section: String, CaseIterable { case lens = "Lens", settings = "Settings" }

    private let capture: ScreenCapturing
    private let client: GeminiResponding
    private let keys: APIKeyManaging
    private let prompts: PromptManaging
    private let configuration: ConfigurationStoring
    private let processor = ImageProcessor()
    private let selector = RegionSelector()
    private var task: Task<Void, Never>?
    private var revision = UUID()
    private var lastProcessed: ImageFingerprint?
    private(set) var overlay: AnswerOverlay?

    init(capture: ScreenCapturing? = nil, client: GeminiResponding = GeminiClient(),
         keys: APIKeyManaging = APIKeyManager(), prompts: PromptManaging = PromptManager(),
         configuration: ConfigurationStoring = ConfigurationStore()) {
        self.capture = capture ?? ScreenCaptureManager()
        self.client = client; self.keys = keys; self.prompts = prompts; self.configuration = configuration
        settings = configuration.load()
        prompt = prompts.load()
        do { hasAPIKey = try keys.read() != nil } catch { errorMessage = error.localizedDescription }
    }

    var defaultPrompt: String { prompts.defaultPrompt }
    var hasScreenPermission: Bool { capture.hasPermission }
    var canAsk: Bool { settings.region != nil && hasAPIKey && !isBusy && !isMonitoring && !isSelecting }

    func installOverlay() { if overlay == nil { overlay = AnswerOverlay(model: self) } }

    func stop() {
        revision = UUID()
        task?.cancel(); task = nil
        capture.reset()
        isMonitoring = false; isBusy = false
        status = "Paused"
    }

    func toggleMonitoring() { isMonitoring ? stop() : startMonitoring() }

    func startMonitoring() {
        guard settings.mode == .auto, !isSelecting else { return }
        launch(automatic: true)
    }

    func askNow() {
        guard !isSelecting, !isMonitoring, !isBusy else { return }
        launch(automatic: false)
    }

    private func launch(automatic: Bool) {
        stop()
        errorMessage = nil
        guard let region = settings.region else { fail(LensError.regionRequired); return }
        guard capture.hasPermission else { fail(LensError.permissionRequired); return }
        guard hasAPIKey else { section = .settings; fail(LensError.keyRequired); return }
        let pass = revision
        let snapshot = settings
        let requestPrompt = prompt
        isMonitoring = automatic
        isBusy = true
        status = "Preparing capture…"
        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await capture.prepare(for: region)
                try validate(pass)
                if automatic {
                    isBusy = false
                    await monitor(region: region, settings: snapshot, prompt: requestPrompt, pass: pass)
                } else {
                    let image = try await capture.capture(region)
                    try validate(pass)
                    let prepared = try await prepare(image)
                    _ = try await request(prepared, prompt: requestPrompt, pass: pass)
                    try validate(pass)
                    isBusy = false
                    status = "Answer ready"
                }
            } catch is CancellationError {
                // The new run owns UI state after cancellation.
            } catch {
                guard revision == pass else { return }
                isBusy = false; isMonitoring = false
                capture.reset()
                fail(error)
            }
        }
    }

    private func monitor(region: ScreenRegion, settings: LensSettings, prompt: String, pass: UUID) async {
        var detector = ContentChangeDetector(threshold: settings.threshold, debounce: settings.debounce,
                                             lastProcessed: lastProcessed)
        var failureCount = 0
        while !Task.isCancelled && revision == pass {
            var delay = settings.captureInterval
            do {
                status = "Watching for changes"
                let image = try await capture.capture(region)
                try validate(pass)
                let fingerprint = try await fingerprint(image)
                if detector.observe(fingerprint, at: ProcessInfo.processInfo.systemUptime) {
                    // Re-capture after stability: never send the image that started debounce.
                    let finalImage = try await capture.capture(region)
                    try validate(pass)
                    let prepared = try await prepare(finalImage)
                    if detector.observe(prepared.fingerprint, at: ProcessInfo.processInfo.systemUptime) {
                        _ = try await request(prepared, prompt: prompt, pass: pass)
                        try validate(pass)
                        detector.markProcessed(prepared.fingerprint)
                        failureCount = 0
                        errorMessage = nil
                    }
                }
            } catch is CancellationError { return }
            catch {
                guard revision == pass else { return }
                isBusy = false
                failureCount += 1
                fail(error)
                if let lensError = error as? LensError {
                    switch lensError {
                    case .permissionRequired, .displayUnavailable, .invalidRegion, .keyRequired, .keyStorage:
                        isMonitoring = false; capture.reset(); return
                    case .http(let code) where (400..<500).contains(code):
                        isMonitoring = false; capture.reset(); return
                    case .rateLimited(let seconds): delay = seconds
                    default: delay = min(60, pow(2, Double(min(failureCount, 6))))
                    }
                } else { delay = min(60, pow(2, Double(min(failureCount, 6)))) }
                status = "Retrying in \(Int(delay.rounded(.up)))s"
            }
            do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            catch { return }
        }
    }

    private func fingerprint(_ image: CGImage) async throws -> ImageFingerprint {
        try await Task.detached(priority: .utility) { [processor] in try processor.fingerprint(image) }.value
    }
    private func prepare(_ image: CGImage) async throws -> PreparedImage {
        try await Task.detached(priority: .utility) { [processor] in try processor.prepare(image) }.value
    }
    private func request(_ image: PreparedImage, prompt: String, pass: UUID) async throws -> String {
        try validate(pass)
        guard let key = try keys.read(), !key.isEmpty else { throw LensError.keyRequired }
        isBusy = true
        status = "Reading your region…"
        requestCount += 1
        let text = try await client.answer(image: image.png, prompt: prompt, apiKey: key)
        try validate(pass)
        answer = text; answeredAt = Date()
        lastProcessed = image.fingerprint
        isBusy = false
        if showsOverlay { overlay?.show(near: settings.region) }
        return text
    }
    private func validate(_ pass: UUID) throws {
        try Task.checkCancellation()
        guard pass == revision else { throw CancellationError() }
    }
    private func fail(_ error: Error) { errorMessage = error.localizedDescription; status = "Needs attention" }

    func chooseRegion() {
        guard !isSelecting else { return }
        stop(); overlay?.hide()
        isSelecting = true
        status = "Choose a region"
        selector.select { [weak self] region in
            guard let self else { return }
            isSelecting = false
            guard let region else { status = "Selection cancelled"; return }
            var updated = settings
            updated.region = region
            do {
                try configuration.save(updated)
                settings = updated
                overlay?.resetPlacement()
                lastProcessed = nil
                answer = ""; answeredAt = nil; errorMessage = nil
                status = "Region selected"
            } catch { fail(error) }
        }
    }

    func update(settings updated: LensSettings, prompt updatedPrompt: String) throws {
        guard !updatedPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LensError.emptyPrompt }
        let resume = isMonitoring && updated.mode == .auto
        stop()
        try prompts.save(updatedPrompt)
        try configuration.save(updated)
        if prompt != updatedPrompt || settings.region != updated.region { lastProcessed = nil }
        settings = updated.normalized(); prompt = updatedPrompt
        errorMessage = nil; status = "Settings saved"
        if resume { startMonitoring() }
    }

    func savePrompt(_ updatedPrompt: String) throws {
        try update(settings: settings, prompt: updatedPrompt)
        status = "Prompt saved"
    }

    func changeMode(_ mode: CaptureMode) {
        var updated = settings; updated.mode = mode
        do { try update(settings: updated, prompt: prompt) } catch { fail(error) }
    }
    func saveKey(_ key: String) throws {
        let resume = isMonitoring
        stop()
        try keys.save(key)
        lastProcessed = nil
        hasAPIKey = true; errorMessage = nil; status = "API key saved"
        if resume { startMonitoring() }
    }
    func deleteKey() throws {
        stop(); try keys.delete()
        lastProcessed = nil
        hasAPIKey = false; status = "API key removed"
    }
    func requestScreenPermission() {
        // Only called by the user's explicit permission button.
        if !CGRequestScreenCaptureAccess() {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
        objectWillChange.send()
    }
    func copyAnswer() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(answer, forType: .string)
    }
    func revealOverlay() { if !answer.isEmpty { overlay?.show(near: settings.region) } }
}
