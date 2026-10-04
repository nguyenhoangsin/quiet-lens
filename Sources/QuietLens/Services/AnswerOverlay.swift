import AppKit
import SwiftUI

@MainActor
final class AnswerOverlay {
    private let panel: PassivePanel
    private var positioned = false
    private var positionedRegion: ScreenRegion?
    private var positionedScreenFrame: CGRect?
    private var positionedVisibleFrame: CGRect?

    init(model: QuietLensViewModel) {
        panel = PassivePanel(contentRect: CGRect(origin: .zero, size: OverlayPlacement.preferredSize),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let contentView = NSHostingView(rootView: OverlayView(model: model, close: { [weak self] in self?.hide() }))
        contentView.sizingOptions = []
        panel.contentView = contentView
    }

    func show(near region: ScreenRegion?) {
        let screen = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == region?.displayID
        } ?? NSScreen.main
        if let screen,
           !positioned || positionedRegion != region || positionedScreenFrame != screen.frame
            || positionedVisibleFrame != screen.visibleFrame
            || !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) {
            let selected = region.map {
                CGRect(x: screen.frame.minX + $0.rect.minX,
                       y: screen.frame.maxY - $0.rect.maxY,
                       width: $0.rect.width, height: $0.rect.height)
            }
            panel.setFrame(OverlayPlacement.frame(near: selected, in: screen.visibleFrame), display: true)
            positioned = true
            positionedRegion = region
            positionedScreenFrame = screen.frame
            positionedVisibleFrame = screen.visibleFrame
        }
        // Never activate the app, make a key window, or change the foreground application.
        panel.orderFrontRegardless()
    }
    func hide() { panel.orderOut(nil) }
    func resetPlacement() { positioned = false }
}

private final class PassivePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct OverlayView: View {
    @ObservedObject var model: QuietLensViewModel
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                OverlayDragHandle()
                    .frame(maxWidth: .infinity).frame(height: 24)
                    .help("Drag this header to move the overlay")
                Button(action: model.copyAnswer) { Image(systemName: "doc.on.doc") }
                    .help("Copy answer")
                Button(action: close) { Image(systemName: "xmark") }.help("Hide overlay")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            ScrollView {
                Text(model.answer).font(.system(size: 14)).lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let date = model.answeredAt {
                Text(date, style: .time).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.quaternary, lineWidth: 1) }
    }
}

private struct OverlayDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragHeaderView { DragHeaderView() }
    func updateNSView(_ nsView: DragHeaderView, context: Context) {}
}

/// A native drag surface keeps movement reliable without making the passive panel key.
private final class DragHeaderView: NSView {
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "QuietLens")

    override init(frame: NSRect) {
        super.init(frame: frame)
        icon.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: nil)
        icon.contentTintColor = .systemTeal
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.textColor = .secondaryLabelColor
        addSubview(icon)
        addSubview(title)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("QuietLens. Drag to move the answer overlay.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        icon.frame = CGRect(x: 0, y: (bounds.height - 16) / 2, width: 16, height: 16)
        title.frame = CGRect(x: 23, y: (bounds.height - 18) / 2, width: max(0, bounds.width - 23), height: 18)
    }
    override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point) == nil ? nil : self }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
    override func mouseDown(with event: NSEvent) {
        NSCursor.closedHand.set()
        window?.performDrag(with: event)
        NSCursor.openHand.set()
    }
}
