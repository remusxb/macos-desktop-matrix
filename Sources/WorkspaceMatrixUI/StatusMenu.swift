import AppKit
import SwiftUI

/// The menu bar icon, with Settings… and Quit.
@MainActor
public final class StatusMenu: NSObject, NSWindowDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let model: SettingsModel
    private var window: NSWindow?

    /// The settings window edits `model`.
    public init(model: SettingsModel) {
        self.model = model
        super.init()
        item.button?.image = NSImage(
            systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: "Workspace Matrix")
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Workspace Matrix", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
    }

    @objc private func openSettings() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "Workspace Matrix"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    /// Closing mid-recording must not leave the app's keys paused.
    public func windowWillClose(_ notification: Notification) {
        model.stopRecording()
    }
}
