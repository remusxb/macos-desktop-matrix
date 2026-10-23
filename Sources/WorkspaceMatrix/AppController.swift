import CoreGraphics
import WorkspaceMatrixCore

/// What the app does: its keys move through the grid and switch desktops; every desktop change, whoever
/// makes it, is tracked and refreshes that desktop's preview; but the grid shows only for the app's own keys.
@MainActor
final class AppController {
    private(set) var config: Config
    private var grid: Grid
    /// The desktop the grid shows: ahead of macOS while a switch is under way.
    private var current = 0

    private let desktops: any DesktopsInterface
    private let switcher: any DesktopSwitcherInterface
    private let overlay: any OverlayInterface
    private let capture: any ScreenCaptureInterface
    private let hotKeys: any HotKeysInterface
    private let saveConfig: (Config) -> Void
    private lazy var navigator = Navigator(
        switchTo: { [unowned self] in switcher.switchTo($0, instant: config.instant) },
        currentDesktop: { [unowned self] in desktops.state().index })

    init(
        config: Config, desktops: any DesktopsInterface, switcher: any DesktopSwitcherInterface,
        overlay: any OverlayInterface, capture: any ScreenCaptureInterface, hotKeys: any HotKeysInterface,
        saveConfig: @escaping (Config) -> Void
    ) {
        self.config = config
        grid = config.grid
        self.desktops = desktops
        self.switcher = switcher
        self.overlay = overlay
        self.capture = capture
        self.hotKeys = hotKeys
        self.saveConfig = saveConfig
    }

    /// Takes the keys and builds a preview of every desktop.
    func start() {
        registerHotKeys()
        Task {
            for (desktop, image) in await capture.composeAll(size: overlay.previewPixelSize) {
                overlay.setPreview(desktop, image, onlyIfMissing: true)  // a real screenshot taken meanwhile wins
            }
        }
        Log.app.notice("\(self.grid.rows)x\(self.grid.cols) grid ready")
    }

    /// New settings: saved, applied, and the grid shown so their effect is visible.
    func apply(_ new: Config) {
        config = new
        grid = new.grid
        saveConfig(new)
        overlay.configure(rows: grid.rows, cols: grid.cols, tileWidth: new.tileWidth, hideAfter: new.hideAfter)
        registerHotKeys()
        overlay.show(desktops.state().index ?? current)
    }

    /// Stops the app's keys while the settings window records a combo, so it sees them instead.
    func pauseHotKeys(_ paused: Bool) {
        if paused {
            hotKeys.unregisterAll()
        } else {
            registerHotKeys()
        }
    }

    /// One of the app's keys: a step on the grid.
    func move(_ direction: Direction) {
        let state = desktops.state()
        // While the grid is up, trust our own position: macOS may still be switching to the last one.
        let from = overlay.isShown ? current : state.index ?? current
        let to = grid.move(from: from, direction)
        // Tiles past the last desktop don't exist (Mission Control's + adds desktops).
        go(to: to < state.count ? to : from, from: from)
    }

    /// macOS changed desktop: through the app's keys, or a swipe, a shortcut, Mission Control.
    func desktopDidChange() {
        let ours = navigator.isNavigating
        guard let desktop = desktops.state().index, navigator.arrived(at: desktop), desktop < grid.count else { return }
        current = desktop
        // Only the app's own keys bring the grid up; it stays until their switch lands.
        if ours || overlay.isShown { overlay.show(desktop) }
        refreshPreview(of: desktop, after: config.instant ? Timing.instantSettle : Timing.slideSettle)
    }

    private func go(to desktop: Int, from: Int) {
        let leaving = !overlay.isShown
        current = desktop
        overlay.show(desktop)
        guard desktop != from else { return }
        if leaving {
            // Snapshot the desktop being left only at the start of a move: ones passed mid-move may not be drawn yet.
            navigator.holding = true
            Task {
                if let image = await capture.capture(size: overlay.previewPixelSize) {
                    overlay.setPreview(from, image, onlyIfMissing: false)
                }
                navigator.holding = false
            }
        }
        navigator.request(desktop)
    }

    /// Screenshots `desktop` once its switch has settled, if it's still the one showing.
    private func refreshPreview(of desktop: Int, after delay: Duration) {
        Task {
            try? await Task.sleep(for: delay)
            guard desktops.state().index == desktop,
                  let image = await capture.capture(size: overlay.previewPixelSize)
            else { return }
            overlay.setPreview(desktop, image, onlyIfMissing: false)
        }
    }

    private func registerHotKeys() {
        hotKeys.unregisterAll()
        for direction in Direction.allCases {
            guard let combo = config.keys[direction] else { continue }
            hotKeys.register(combo) { [weak self] in self?.move(direction) }
        }
    }

    /// How long a switch takes to finish drawing before its screenshot is worth taking.
    private enum Timing {
        static let slideSettle: Duration = .milliseconds(500)
        static let instantSettle: Duration = .milliseconds(150)
    }
}
