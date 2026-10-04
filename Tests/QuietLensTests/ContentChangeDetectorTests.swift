import Testing
@testable import QuietLens

struct ContentChangeDetectorTests {
    private func image(_ level: UInt8) -> ImageFingerprint { .init(pixels: Array(repeating: level, count: 128 * 96)) }

    @Test func testFirstImageWaitsForDebounceAndProcessedImageIsNotSentAgain() {
        var detector = ContentChangeDetector(threshold: 0.02, debounce: 1)
        let changed1 = detector.observe(image(80), at: 0)
        #expect(!changed1)
        let changed2 = detector.observe(image(80), at: 0.9)
        #expect(!changed2)
        let changed3 = detector.observe(image(80), at: 1.1)
        #expect(changed3)
        detector.markProcessed(image(80))
        let changed4 = detector.observe(image(80), at: 10)
        #expect(!changed4)
        let changed5 = detector.observe(image(82), at: 20)
        #expect(!changed5)
    }

    @Test func testMovingContentRestartsDebounceAndFinalCaptureMustBeStable() {
        var detector = ContentChangeDetector(threshold: 0.02, debounce: 1)
        let changed6 = detector.observe(image(20), at: 0)
        #expect(!changed6)
        let changed7 = detector.observe(image(60), at: 0.8)
        #expect(!changed7)
        let changed8 = detector.observe(image(60), at: 1.5)
        #expect(!changed8)
        let changed9 = detector.observe(image(60), at: 1.9)
        #expect(changed9)
        // Fresh capture changed after the debounce candidate became ready.
        let changed10 = detector.observe(image(100), at: 1.95)
        #expect(!changed10)
        let changed11 = detector.observe(image(100), at: 3)
        #expect(changed11)
    }

    @Test func testCumulativeSmallChangesAreComparedToStableAnchor() {
        var detector = ContentChangeDetector(threshold: 0.02, debounce: 1)
        let changed12 = detector.observe(image(0), at: 0)
        #expect(!changed12)
        let changed13 = detector.observe(image(3), at: 0.5)
        #expect(!changed13)
        let changed14 = detector.observe(image(6), at: 1)
        #expect(!changed14)
        let changed15 = detector.observe(image(9), at: 1.5)
        #expect(!changed15)
        let changed16 = detector.observe(image(12), at: 2)
        #expect(!changed16)
        let changed17 = detector.observe(image(12), at: 3.1)
        #expect(changed17)
    }

    @Test func testFailureDoesNotCommitBaselineAndReturningToOldContentCancelsCandidate() {
        var detector = ContentChangeDetector(threshold: 0.02, debounce: 1)
        detector.markProcessed(image(0))
        let changed18 = detector.observe(image(80), at: 0)
        #expect(!changed18)
        let changed19 = detector.observe(image(80), at: 1.1)
        #expect(changed19)
        // No markProcessed call when a request fails: the same image can retry.
        let changed20 = detector.observe(image(80), at: 5)
        #expect(changed20)
        let changed21 = detector.observe(image(0), at: 6)
        #expect(!changed21)
        let changed22 = detector.observe(image(80), at: 6.1)
        #expect(!changed22)
        let changed23 = detector.observe(image(80), at: 7.2)
        #expect(changed23)
    }
}
