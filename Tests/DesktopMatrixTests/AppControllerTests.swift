import CoreGraphics
import DesktopMatrixCore
import Testing

@testable import DesktopMatrix

@MainActor
private final class FakeDesktops: DesktopsInterface {
    var now = DesktopState(index: 0, count: 16)
    func state() -> DesktopState { now }
}

@MainActor
private final class FakeSwitcher: DesktopSwitcherInterface {
    var switches: [(desktop: Int, instant: Bool)] = []
    func switchTo(_ desktop: Int, instant: Bool) { switches.append((desktop, instant)) }
}

@MainActor
private final class FakeOverlay: OverlayInterface {
    var isShown = false
    var shown: [Int] = []
    var configured: (rows: Int, cols: Int)?
    let previewPixelSize = CGSize(width: 32, height: 20)
    func configure(rows: Int, cols: Int, tileWidth: Double, hideAfter: Double) { configured = (rows, cols) }
    func show(_ desktop: Int) {
        isShown = true
        shown.append(desktop)
    }
    func setPreview(_ desktop: Int, _ image: CGImage, onlyIfMissing: Bool) {}
}

@MainActor
private final class FakeCapture: ScreenCaptureInterface {
    func capture(size: CGSize) async -> CGImage? { nil }
    func composeAll(size: CGSize) async -> [Int: CGImage] { [:] }
}

@MainActor
private final class FakeHotKeys: HotKeysInterface {
    var actions: [KeyCombo: @MainActor () -> Void] = [:]
    func register(_ combo: KeyCombo, _ action: @escaping @MainActor () -> Void) -> Bool {
        actions[combo] = action
        return true
    }
    func unregisterAll() { actions.removeAll() }
    func press(_ direction: Direction) { actions[Config.defaultKeys[direction]!]?() }
}

/// An AppController on a 4×4 grid of 16 fake desktops.
@MainActor
private final class Harness {
    let desktops = FakeDesktops()
    let switcher = FakeSwitcher()
    let overlay = FakeOverlay()
    let hotKeys = FakeHotKeys()
    var saved: [Config] = []
    lazy var controller: AppController = {
        var config = Config()
        config.rows = 4
        config.cols = 4
        return AppController(
            config: config, desktops: desktops, switcher: switcher, overlay: overlay, capture: FakeCapture(),
            hotKeys: hotKeys, saveConfig: { self.saved.append($0) })
    }()

    init() { controller.start() }

    /// Lets the snapshot taken before a switch finish, so the switch goes out.
    func settle() async {
        for _ in 0..<10 { await Task.yield() }
    }
}

@MainActor @Test func aKeyShowsTheGridAndSwitches() async {
    let app = Harness()
    app.hotKeys.press(.down)
    await app.settle()
    #expect(app.overlay.shown == [4])
    #expect(app.switcher.switches.map(\.desktop) == [4])
}

@MainActor @Test func switchesFromElsewhereAreTrackedQuietly() async {
    let app = Harness()
    app.desktops.now.index = 5  // a swipe, or a macOS shortcut
    app.controller.desktopDidChange()
    #expect(app.overlay.shown.isEmpty)
    app.hotKeys.press(.right)
    await app.settle()
    #expect(app.switcher.switches.map(\.desktop) == [6])  // the next key starts from where macOS is
}

@MainActor @Test func theGridStaysUpUntilOurSwitchLands() async {
    let app = Harness()
    app.hotKeys.press(.right)
    await app.settle()
    app.overlay.isShown = false  // the switch took longer than the grid stays up
    app.desktops.now.index = 1
    app.controller.desktopDidChange()
    #expect(app.overlay.shown == [1, 1])
}

@MainActor @Test func tilesPastTheLastDesktopCantBeReached() async {
    let app = Harness()
    app.desktops.now = DesktopState(index: 1, count: 3)
    app.hotKeys.press(.down)
    await app.settle()
    #expect(app.switcher.switches.isEmpty)
    #expect(app.overlay.shown == [1])  // the grid still shows where you are
}

@MainActor @Test func theSwitchModeComesFromTheSettings() async {
    let app = Harness()
    var config = app.controller.config
    config.instant = true
    app.controller.apply(config)
    app.overlay.isShown = false
    app.hotKeys.press(.right)
    await app.settle()
    #expect(app.switcher.switches.last?.instant == true)
}

@MainActor @Test func newSettingsAreSavedAndApplied() {
    let app = Harness()
    var config = app.controller.config
    config.rows = 2
    config.keys[.up] = KeyCombo("alt+k")
    app.controller.apply(config)
    #expect(app.saved == [config])
    #expect(app.overlay.configured?.rows == 2)
    #expect(app.hotKeys.actions[KeyCombo("alt+k")!] != nil)
    #expect(app.hotKeys.actions[Config.defaultKeys[.up]!] == nil)
}

@MainActor @Test func recordingAComboPausesTheKeys() {
    let app = Harness()
    app.controller.pauseHotKeys(true)
    #expect(app.hotKeys.actions.isEmpty)
    app.controller.pauseHotKeys(false)
    #expect(app.hotKeys.actions.count == Direction.allCases.count)
}
