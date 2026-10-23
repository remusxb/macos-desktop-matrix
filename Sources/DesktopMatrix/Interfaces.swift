import AppKit
import DesktopMatrixCore
import DesktopMatrixSystem
import DesktopMatrixUI

// What AppController needs from the rest of the app, declared here by the one that uses it, so tests can
// hand it fakes. The real types conform below.

/// Reads where macOS is.
@MainActor
protocol DesktopsInterface {
    func state() -> DesktopState
}

/// Switches desktops.
@MainActor
protocol DesktopSwitcherInterface {
    func switchTo(_ desktop: Int, instant: Bool)
}

/// The grid on screen.
@MainActor
protocol OverlayInterface: AnyObject {
    var isShown: Bool { get }
    var previewPixelSize: CGSize { get }
    func configure(rows: Int, cols: Int, tileWidth: Double, hideAfter: Double)
    func show(_ desktop: Int)
    func setPreview(_ desktop: Int, _ image: CGImage, onlyIfMissing: Bool)
}

/// Takes desktop previews.
@MainActor
protocol ScreenCaptureInterface: AnyObject {
    func capture(size: CGSize) async -> CGImage?
    func composeAll(size: CGSize) async -> [Int: CGImage]
}

/// Global key combos.
@MainActor
protocol HotKeysInterface: AnyObject {
    @discardableResult
    func register(_ combo: KeyCombo, _ action: @escaping @MainActor () -> Void) -> Bool
    func unregisterAll()
}

extension Desktops: DesktopsInterface {}
extension DesktopSwitcher: DesktopSwitcherInterface {}
extension Overlay: OverlayInterface {}
extension ScreenCapture: ScreenCaptureInterface {}
extension HotKeys: HotKeysInterface {}
