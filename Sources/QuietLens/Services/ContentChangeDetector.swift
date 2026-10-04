import Foundation

struct ImageFingerprint: Equatable {
    let pixels: [UInt8]

    /// Mean absolute luminance difference, normalized to 0…1.
    func difference(from other: Self) -> Double {
        guard pixels.count == other.pixels.count, !pixels.isEmpty else { return 1 }
        let sum = zip(pixels, other.pixels).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        return Double(sum) / Double(pixels.count * 255)
    }
}

/// Pure state machine. Only successful AI responses commit the processed baseline.
struct ContentChangeDetector {
    let threshold: Double
    let debounce: TimeInterval
    private(set) var lastProcessed: ImageFingerprint?
    private var candidate: ImageFingerprint?
    private var stableSince: TimeInterval?

    init(threshold: Double, debounce: TimeInterval, lastProcessed: ImageFingerprint? = nil) {
        self.threshold = threshold
        self.debounce = debounce
        self.lastProcessed = lastProcessed
    }

    mutating func observe(_ image: ImageFingerprint, at time: TimeInterval) -> Bool {
        if let lastProcessed, image.difference(from: lastProcessed) < threshold {
            candidate = nil
            stableSince = nil
            return false
        }
        guard let candidate, let stableSince else {
            self.candidate = image
            self.stableSince = time
            return false
        }
        // Compare against an anchor, so small cumulative animation changes reset debounce.
        if image.difference(from: candidate) >= threshold {
            self.candidate = image
            self.stableSince = time
            return false
        }
        return time - stableSince >= debounce
    }

    mutating func markProcessed(_ image: ImageFingerprint) {
        lastProcessed = image
        candidate = nil
        stableSince = nil
    }
}
