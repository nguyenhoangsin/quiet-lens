import Testing
import Foundation
@testable import QuietLens

struct ConfigurationTests {
    @Test func testPromptAndRegionRestoreAcrossManagers() throws {
        let name = "QuietLensTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let prompts = PromptManager(defaults: defaults)
        #expect(prompts.defaultPrompt.hasPrefix("Read the question shown in the screenshot."))
        #expect(prompts.defaultPrompt.contains("- show the correct answer first"))
        #expect(prompts.load() == prompts.defaultPrompt)
        try prompts.save("Explain in Vietnamese")
        #expect(PromptManager(defaults: defaults).load() == "Explain in Vietnamese")
        #expect(throws: (any Error).self) { try prompts.save("\n  ") }
        #expect(prompts.load() == "Explain in Vietnamese")
        var settings = LensSettings()
        settings.region = ScreenRegion(displayID: 42, displayName: "External", displaySize: CGSize(width: 1920, height: 1080),
                                       rect: CGRect(x: 30, y: 40, width: 600, height: 300))
        settings.mode = .manual
        settings.captureInterval = 1.2
        try ConfigurationStore(defaults: defaults).save(settings)
        #expect(ConfigurationStore(defaults: defaults).load() == settings)
        #expect(defaults.string(forKey: "gemini-api-key") == nil)
    }

    @Test func testInvalidPersistedValuesAreBoundedBeforeTimersAndCapture() {
        var settings = LensSettings()
        settings.threshold = .nan
        settings.captureInterval = -2
        settings.debounce = 100
        settings.region = ScreenRegion(displayID: 1, displayName: "Invalid", displaySize: CGSize(width: 100, height: 100),
                                       rect: CGRect(x: 90, y: 0, width: 50, height: 40))
        let fixed = settings.normalized()
        #expect(fixed.threshold == 0.02)
        #expect(fixed.captureInterval == 0.3)
        #expect(fixed.debounce == 10)
        #expect(fixed.region == nil)
    }

    @Test func originalDefaultTimingIsUpgradedOnce() throws {
        let name = "QuietLensTimingTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var previous = LensSettings()
        previous.captureInterval = 0.6
        previous.debounce = 1.0
        previous.mode = .manual
        previous.threshold = 0.025
        defaults.set(try JSONEncoder().encode(previous), forKey: "lens.settings")
        let store = ConfigurationStore(defaults: defaults)
        let upgraded = store.load()
        #expect(upgraded.captureInterval == 5)
        #expect(upgraded.debounce == 2)
        #expect(upgraded.mode == .manual)
        #expect(upgraded.threshold == 0.025)
        #expect(store.load() == upgraded)
        // An explicit choice after migration must not be overridden again.
        try store.save(previous)
        #expect(store.load() == previous)
    }

    @Test func previousDefaultThresholdIsUpgradedOnce() throws {
        let name = "QuietLensThresholdTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var previous = LensSettings()
        previous.threshold = 0.012
        previous.captureInterval = 12
        defaults.set(try JSONEncoder().encode(previous), forKey: "lens.settings")
        defaults.set(1, forKey: "lens.settings.version")
        let store = ConfigurationStore(defaults: defaults)
        let upgraded = store.load()
        #expect(upgraded.threshold == 0.02)
        #expect(upgraded.captureInterval == 12)
        #expect(store.load() == upgraded)
        try store.save(previous)
        #expect(store.load() == previous)
    }

    @Test func customizedSlowTimingSurvivesLoading() throws {
        let name = "QuietLensTimingTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var previous = LensSettings()
        previous.captureInterval = 12
        previous.debounce = 4
        defaults.set(try JSONEncoder().encode(previous), forKey: "lens.settings")
        #expect(ConfigurationStore(defaults: defaults).load() == previous)
    }
}
