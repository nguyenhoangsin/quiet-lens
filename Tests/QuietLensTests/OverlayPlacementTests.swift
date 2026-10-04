import CoreGraphics
import Testing
@testable import QuietLens

struct OverlayPlacementTests {
    private let screen = CGRect(x: 0, y: 40, width: 1920, height: 1016)

    @Test func prefersRightEdgeAndCentersVertically() {
        let selected = CGRect(x: 100, y: 800, width: 600, height: 200)
        let frame = OverlayPlacement.frame(near: selected, in: screen)
        #expect(frame.size == CGSize(width: 360, height: 320))
        #expect(frame.minX == selected.maxX + 12)
        #expect(frame.midY == screen.midY)
        #expect(screen.contains(frame))
    }

    @Test func usesLeftSideOnlyWhenRightSideDoesNotFit() {
        let selected = CGRect(x: 1300, y: 100, width: 500, height: 200)
        let frame = OverlayPlacement.frame(near: selected, in: screen)
        #expect(frame.maxX == selected.minX - 12)
        #expect(frame.midY == screen.midY)
        #expect(screen.contains(frame))
    }

    @Test func fallsBackInsideScreenWhenNeitherSideFits() {
        let selected = CGRect(x: 50, y: 100, width: 1820, height: 800)
        let frame = OverlayPlacement.frame(near: selected, in: screen)
        #expect(frame.maxX == screen.maxX - 12)
        #expect(frame.midY == screen.midY)
        #expect(screen.contains(frame))
    }

    @Test func handlesDisplayLeftOfPrimaryDisplay() {
        let external = CGRect(x: -1920, y: -300, width: 1920, height: 1080)
        let selected = CGRect(x: -1800, y: -100, width: 700, height: 300)
        let frame = OverlayPlacement.frame(near: selected, in: external)
        #expect(frame.minX == selected.maxX + 12)
        #expect(frame.midY == external.midY)
        #expect(external.contains(frame))
    }

    @Test func constrainsPanelToSmallDisplay() {
        let small = CGRect(x: 100, y: 50, width: 320, height: 300)
        let frame = OverlayPlacement.frame(near: nil, in: small)
        #expect(frame.width == 296)
        #expect(frame.height == 276)
        #expect(frame.midY == small.midY)
        #expect(small.contains(frame))
    }
}
