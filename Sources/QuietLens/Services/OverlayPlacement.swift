import CoreGraphics

enum OverlayPlacement {
    static let preferredSize = CGSize(width: 360, height: 320)

    /// AppKit desktop coordinates. Prefer beside the tracked region, without overflowing the display.
    static func frame(near selected: CGRect?, in visibleFrame: CGRect) -> CGRect {
        let margin: CGFloat = 12
        let available = visibleFrame.insetBy(dx: min(margin, visibleFrame.width / 4),
                                             dy: min(margin, visibleFrame.height / 4))
        let size = CGSize(width: min(preferredSize.width, available.width),
                          height: min(preferredSize.height, available.height))
        let minX = available.minX
        let maxX = available.maxX - size.width
        var x = maxX
        if let selected {
            let right = selected.maxX + margin
            let left = selected.minX - margin - size.width
            if right >= minX && right <= maxX {
                x = right
            } else if left >= minX && left <= maxX {
                x = left
            }
        }
        return CGRect(x: x, y: visibleFrame.midY - size.height / 2, width: size.width, height: size.height)
    }
}
