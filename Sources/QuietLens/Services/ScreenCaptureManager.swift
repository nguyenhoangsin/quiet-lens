import AppKit
import ScreenCaptureKit

@MainActor
protocol ScreenCapturing {
    var hasPermission: Bool { get }
    func prepare(for region: ScreenRegion) async throws
    func capture(_ region: ScreenRegion) async throws -> CGImage
    func reset()
}

@MainActor
final class ScreenCaptureManager: ScreenCapturing {
    private var filter: SCContentFilter?
    private var displayID: CGDirectDisplayID?
    private var revision = UUID()

    var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    func prepare(for region: ScreenRegion) async throws {
        let pass = UUID()
        revision = pass
        guard hasPermission else { throw LensError.permissionRequired }
        guard region.isValid else { throw LensError.invalidRegion }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        try Task.checkCancellation()
        guard revision == pass else { throw CancellationError() }
        guard let display = content.displays.first(where: { $0.displayID == region.displayID })
        else { throw LensError.displayUnavailable }
        let ownApplications = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        filter = SCContentFilter(display: display, excludingApplications: ownApplications, exceptingWindows: [])
        displayID = region.displayID
    }

    func capture(_ region: ScreenRegion) async throws -> CGImage {
        guard hasPermission else { throw LensError.permissionRequired }
        guard region.isValid else { throw LensError.invalidRegion }
        guard let filter, displayID == region.displayID,
              CGDisplayIsActive(region.displayID) != 0,
              CGDisplayBounds(region.displayID).size == region.displaySize
        else { throw LensError.displayUnavailable }
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = region.rect
        let scale = min(Double(filter.pointPixelScale), 1800 / max(region.rect.width, region.rect.height))
        configuration.width = max(1, Int((region.rect.width * scale).rounded()))
        configuration.height = max(1, Int((region.rect.height * scale).rounded()))
        configuration.showsCursor = false
        configuration.capturesAudio = false
        configuration.ignoreShadowsDisplay = true
        // The screenshot manager captures just the configured crop. No activation or permission prompt here.
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }

    func reset() { revision = UUID(); filter = nil; displayID = nil }
}
