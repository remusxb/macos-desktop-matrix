import AppKit
import WorkspaceMatrixCore
import WorkspaceMatrixSystem
import WorkspaceMatrixUI

// Wiring only: what the app does is in AppController.

// One instance: a second one (say, opened from Finder while launchd runs it) would draw a second grid.
if let id = Bundle.main.bundleIdentifier, NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
    Log.app.notice("already running, quitting")
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // no Dock icon
Permissions.requestAccessibility()
Permissions.requestScreenRecording()

let configFile = ConfigFile.standard
let config = configFile.load()
let desktops = Desktops()
let overlay = Overlay(
    rows: config.rows, cols: config.cols, tileWidth: config.tileWidth, hideAfter: config.hideAfter,
    pin: DesktopPinning.pinAboveDesktops)
let controller = AppController(
    config: config, desktops: desktops, switcher: DesktopSwitcher(desktops: desktops), overlay: overlay,
    capture: ScreenCapture(desktops: desktops), hotKeys: HotKeys(), saveConfig: configFile.save)
let statusMenu = StatusMenu(
    model: SettingsModel(config, onChange: controller.apply, pauseHotKeys: controller.pauseHotKeys))

NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
) { _ in
    MainActor.assumeIsolated { controller.desktopDidChange() }
}

controller.start()
app.run()
