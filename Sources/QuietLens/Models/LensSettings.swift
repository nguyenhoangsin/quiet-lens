import Foundation
import CoreGraphics

enum CaptureMode: String, Codable, CaseIterable, Identifiable {
    case auto, manual
    var id: String { rawValue }
    var title: String { self == .auto ? "Auto" : "Manual" }
}

/// Coordinates in points, relative to the selected display's top-left corner.
struct ScreenRegion: Codable, Equatable {
    let displayID: CGDirectDisplayID
    let displayName: String
    let displaySize: CGSize
    let rect: CGRect

    var description: String { "\(Int(rect.width)) × \(Int(rect.height)) pt · \(displayName)" }

    var isValid: Bool {
        let values = [rect.minX, rect.minY, rect.width, rect.height, displaySize.width, displaySize.height]
        return values.allSatisfy(\.isFinite) && rect.width >= 20 && rect.height >= 20
            && rect.minX >= 0 && rect.minY >= 0
            && rect.maxX <= displaySize.width && rect.maxY <= displaySize.height
    }
}

struct LensSettings: Codable, Equatable {
    var region: ScreenRegion?
    var mode: CaptureMode = .auto
    var threshold: Double = 0.02
    var captureInterval: Double = 5.0
    var debounce: Double = 2.0

    func normalized() -> Self {
        var result = self
        result.threshold = threshold.isFinite ? min(0.08, max(0.002, threshold)) : 0.02
        result.captureInterval = captureInterval.isFinite ? min(30, max(0.3, captureInterval)) : 5.0
        result.debounce = debounce.isFinite ? min(10, max(0.5, debounce)) : 2.0
        if region?.isValid == false { result.region = nil }
        return result
    }
}

enum LensError: LocalizedError {
    case permissionRequired, regionRequired, displayUnavailable, invalidRegion, keyRequired
    case emptyPrompt, imageProcessing, emptyResponse, blockedResponse
    case http(Int), rateLimited(TimeInterval), keyStorage

    var errorDescription: String? {
        switch self {
        case .permissionRequired: return "Allow QuietLens in System Settings → Privacy & Security → Screen Recording, then restart the app."
        case .regionRequired: return "Choose a screen region first."
        case .displayUnavailable: return "The selected display is unavailable or its resolution changed. Choose the region again."
        case .invalidRegion: return "Choose a region at least 20 × 20 points inside one display."
        case .keyRequired: return "Add your Gemini API key in Settings."
        case .emptyPrompt: return "Enter a prompt before saving."
        case .imageProcessing: return "Could not prepare the screen image."
        case .emptyResponse: return "Gemini returned no answer. Try again."
        case .blockedResponse: return "Gemini could not answer this image. Try another region or prompt."
        case .http(let code):
            if code == 400 { return "Gemini rejected the request. Check the image and prompt." }
            if code == 401 || code == 403 { return "Gemini could not authorize this key. Check API access in Google AI Studio." }
            if code == 404 { return "Gemini 3.5 Flash-Lite is unavailable for this API key." }
            return "Gemini is unavailable (HTTP \(code)). Try again shortly."
        case .rateLimited(let seconds): return "Gemini rate limit reached. Retry after \(Int(seconds.rounded(.up))) seconds."
        case .keyStorage: return "The saved API key is invalid. Replace or remove it in Settings."
        }
    }
}
