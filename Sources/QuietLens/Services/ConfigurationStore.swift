import Foundation

protocol ConfigurationStoring {
    func load() -> LensSettings
    func save(_ settings: LensSettings) throws
}

struct ConfigurationStore: ConfigurationStoring {
    let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> LensSettings {
        guard let data = defaults.data(forKey: "lens.settings"),
              var settings = try? JSONDecoder().decode(LensSettings.self, from: data)
        else { return LensSettings() }
        let version = defaults.integer(forKey: "lens.settings.version")
        if version < 1 {
            // Upgrade the original default pair once, preserving customized timing and other settings.
            if settings.captureInterval == 0.6 && settings.debounce == 1.0 {
                settings.captureInterval = 5.0
                settings.debounce = 2.0
            }
        }
        if version < 2 {
            // Replace the previous default once; retain explicitly customized thresholds.
            if settings.threshold == 0.012 { settings.threshold = 0.02 }
            try? save(settings)
        }
        return settings.normalized()
    }
    func save(_ settings: LensSettings) throws {
        defaults.set(try JSONEncoder().encode(settings.normalized()), forKey: "lens.settings")
        defaults.set(2, forKey: "lens.settings.version")
    }
}

protocol PromptManaging {
    var defaultPrompt: String { get }
    func load() -> String
    func save(_ prompt: String) throws
}

struct PromptManager: PromptManaging {
    let defaults: UserDefaults
    let defaultPrompt: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // The document's example is a replaceable resource, never a mandatory instruction.
        defaultPrompt = Bundle.module.url(forResource: "DefaultPrompt", withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func load() -> String { defaults.string(forKey: "lens.prompt") ?? defaultPrompt }
    func save(_ prompt: String) throws {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LensError.emptyPrompt }
        defaults.set(prompt, forKey: "lens.prompt")
    }
}
