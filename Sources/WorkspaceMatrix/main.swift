import AppKit

func log(_ message: String) {
    FileHandle.standardError.write(Data("workspace-matrix: \(message)\n".utf8))
}

// One instance only: a second one (say, opened from Finder while launchd runs it) would draw a second grid.
if let id = Bundle.main.bundleIdentifier, NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
    log("already running, quitting")
    exit(0)
}

var config = Config.load()
var grid = Grid(rows: config.rows, cols: config.cols, wrap: config.wrap)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // no Dock icon

// Switching desktops for the user needs Accessibility permission.
if !AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary) {
    log("no Accessibility permission yet: desktops won't switch until it's granted and the app restarts")
}

let overlay = Overlay(rows: grid.rows, cols: grid.cols, tileWidth: config.tileWidth, hideAfter: config.hideAfter)
let screenCapture = ScreenCapture()
let navigator = Navigator(switchTo: { Desktops.switchTo($0, instant: config.instant) },
                          currentDesktop: { Desktops.state().index })
var current = 0

func go(to index: Int, from: Int) {
    let snapshot = !overlay.isShown
    current = index
    overlay.show(index)
    guard index != from else { return }
    if snapshot {
        // Snapshot the desktop we leave only at the start of a move: ones passed mid-move may not be drawn yet.
        navigator.holding = true
        Task { @MainActor in
            if let image = await screenCapture.capture(size: overlay.previewPixelSize) {
                overlay.setPreview(from, image)
            }
            navigator.holding = false
        }
    }
    navigator.request(index)
}

func move(_ direction: Direction) {
    let desktops = Desktops.state()
    // While the overlay is up we trust our own index: macOS may still be sliding to the previous desktop.
    let from = overlay.isShown ? current : desktops.index ?? current
    let to = grid.move(from: from, direction)
    // Cells past the last desktop don't exist (add desktops with Mission Control's +).
    go(to: to < desktops.count ? to : from, from: from)
}

let hotKeys = HotKeys()

func apply(_ new: Config) {
    config = new
    grid = Grid(rows: config.rows, cols: config.cols, wrap: config.wrap)
    overlay.configure(rows: grid.rows, cols: grid.cols, tileWidth: config.tileWidth)
    overlay.hideAfter = config.hideAfter
    hotKeys.unregisterAll()
    for direction in Direction.allCases {
        guard let combo = config.keys[direction.rawValue] else { continue }
        hotKeys.register(combo) { move(direction) }
    }
}
apply(config)

let statusMenu = StatusMenu(model: SettingsModel(config, onChange: { new in
    apply(new)
    overlay.show(Desktops.state().index ?? current)  // live preview of the change
}, pauseHotKeys: { paused in
    if paused { hotKeys.unregisterAll() } else { apply(config) }
}))

// Track every desktop change (swipes, macOS shortcuts, Mission Control) for position and previews, but
// bring the grid up only for our own keys, keeping it until the switch lands so you see where you arrived.
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
) { _ in
    let ours = navigator.isNavigating
    guard let index = Desktops.state().index, navigator.arrived(at: index), index < grid.count else { return }
    current = index
    if ours || overlay.isShown { overlay.show(index) }
    // Refresh this desktop's preview once the switch has settled, if we're still on it.
    DispatchQueue.main.asyncAfter(deadline: .now() + (config.instant ? 0.15 : 0.5)) {
        guard Desktops.state().index == index else { return }
        Task { @MainActor in
            if let image = await screenCapture.capture(size: overlay.previewPixelSize) { overlay.setPreview(index, image) }
        }
    }
}

// Previews of every desktop right away; real screenshots replace them as you move around.
Task { @MainActor in
    for (index, image) in await screenCapture.composePreviews(size: overlay.previewPixelSize) {
        overlay.setPreview(index, image, onlyIfMissing: true)
    }
}

log("\(grid.rows)x\(grid.cols) grid ready")
app.run()
