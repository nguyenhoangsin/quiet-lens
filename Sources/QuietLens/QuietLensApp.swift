import AppKit
import SwiftUI

@main
@MainActor
struct QuietLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = QuietLensViewModel()

    init() {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) { NSApplication.shared.applicationIconImage = icon }
    }

    var body: some Scene {
        Window("QuietLens", id: "main") {
            QuietLensView().environmentObject(model)
        }
        .defaultSize(width: 660, height: 940)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { model.section = .settings; delegate.showMainWindow() }
                    .keyboardShortcut(",")
            }
        }
        MenuBarExtra {
            LensMenu(model: model)
        } label: {
            Image(systemName: model.isMonitoring ? "viewfinder.circle.fill" : "viewfinder")
        }
    }
}

private struct LensMenu: View {
    @ObservedObject var model: QuietLensViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("QuietLens · \(model.status)")
        Divider()
        Button("Open QuietLens") { show(.lens) }
        Button("Settings…") { show(.settings) }.keyboardShortcut(",")
        Divider()
        Button("Choose region…", action: model.chooseRegion).disabled(model.isSelecting)
        if model.settings.mode == .auto {
            Button(model.isMonitoring ? "Pause monitoring" : "Start monitoring", action: model.toggleMonitoring)
                .disabled(model.isSelecting || (model.isBusy && !model.isMonitoring))
        } else {
            Button("Ask now", action: model.askNow).disabled(!model.canAsk)
        }
        Button("Show answer", action: model.revealOverlay).disabled(model.answer.isEmpty)
        Button("Hide answer") { model.overlay?.hide() }
        Divider()
        Button("Quit QuietLens") { model.stop(); NSApp.terminate(nil) }.keyboardShortcut("q")
    }

    private func show(_ section: QuietLensViewModel.Section) {
        model.section = section
        NSApp.setActivationPolicy(.regular)
        openWindow(id: "main")
        // This activation is only the user's explicit Open / Settings action.
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(self, selector: #selector(mainWindowWillClose(_:)),
                                               name: NSWindow.willCloseNotification, object: nil)
    }

    @objc private func mainWindowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.identifier?.rawValue == "main" || window.title == "QuietLens",
              !(window is NSPanel) else { return }
        // Only closing the main window hides the Dock icon; capture and overlays keep running.
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.windows.first { $0.title == "QuietLens" }?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
    }
}
