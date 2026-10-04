import AppKit

@MainActor
final class RegionSelector {
    private var panels: [NSPanel] = []
    private var completion: ((ScreenRegion?) -> Void)?
    private var escapeMonitor: Any?
    private var previousApplication: NSRunningApplication?

    func select(completion: @escaping (ScreenRegion?) -> Void) {
        guard panels.isEmpty else { return }
        self.completion = completion
        previousApplication = NSWorkspace.shared.frontmostApplication
        for screen in NSScreen.screens {
            guard let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
            else { continue }
            let panel = SelectionPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                                       backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isReleasedWhenClosed = false
            let view = RegionSelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.onCancel = { [weak self] in self?.finish(nil) }
            view.onSelection = { [weak self] rect in
                let topLeftRect = CGRect(x: rect.minX, y: screen.frame.height - rect.maxY,
                                         width: rect.width, height: rect.height)
                let region = ScreenRegion(displayID: displayID, displayName: screen.localizedName,
                                          displaySize: screen.frame.size, rect: topLeftRect)
                self?.finish(region.isValid ? region : nil)
            }
            panel.contentView = view
            panels.append(panel)
            panel.orderFrontRegardless()
        }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.finish(nil); return nil }
            return event
        }
        // Selection is explicitly requested. Only this temporary UI accepts keyboard focus.
        if let panel = panels.first { panel.makeKey(); panel.makeFirstResponder(panel.contentView) }
        else { finish(nil) }
    }

    private func finish(_ region: ScreenRegion?) {
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
        panels.forEach { $0.close() }
        panels.removeAll()
        let callback = completion
        completion = nil
        if let previousApplication, previousApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApplication.activate(options: [])
        }
        previousApplication = nil
        callback?(region)
    }
}

private final class SelectionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class RegionSelectionView: NSView {
    var onSelection: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    private var start: CGPoint?
    private var selection = CGRect.zero
    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() } else { super.keyDown(with: event) }
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        start = convert(event.locationInWindow, from: nil)
        selection = .zero
        needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start else { return }
        let end = convert(event.locationInWindow, from: nil)
        selection = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                           width: abs(start.x - end.x), height: abs(start.y - end.y)).intersection(bounds)
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        guard selection.width >= 20, selection.height >= 20 else {
            start = nil; selection = .zero; needsDisplay = true; return
        }
        onSelection?(selection.integral.intersection(bounds))
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill()
        let shade = NSBezierPath(rect: bounds)
        if !selection.isEmpty { shade.appendRect(selection) }
        shade.windingRule = .evenOdd
        shade.fill()
        if !selection.isEmpty {
            NSColor.systemTeal.setStroke()
            let border = NSBezierPath(rect: selection.insetBy(dx: 1, dy: 1))
            border.lineWidth = 2; border.stroke()
        }
        let text = selection.isEmpty ? "Drag to choose a region · Esc to cancel"
            : "\(Int(selection.width)) × \(Int(selection.height)) pt"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium), .foregroundColor: NSColor.white,
        ]
        let label = NSAttributedString(string: text, attributes: attributes)
        let size = label.size()
        let frame = CGRect(x: (bounds.width - size.width) / 2 - 16, y: bounds.height - 94,
                           width: size.width + 32, height: size.height + 20)
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: frame, xRadius: 12, yRadius: 12).fill()
        label.draw(at: CGPoint(x: frame.minX + 16, y: frame.minY + 10))
    }
}
