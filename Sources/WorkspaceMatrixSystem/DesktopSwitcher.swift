import CoreGraphics
import Foundation
import WorkspaceMatrixCore

/// Switches desktops the way macOS itself does, so Mission Control and swipes always agree with the grid.
public struct DesktopSwitcher: Sendable {
    private let desktops: Desktops

    /// Switches among `desktops`.
    public init(desktops: Desktops) {
        self.desktops = desktops
    }

    /// Normal: presses the user's "Switch to Desktop N" shortcut, so macOS slides there.
    /// Instant: posts trackpad swipes so fast that macOS skips the slide.
    public func switchTo(_ desktop: Int, instant: Bool) {
        if instant {
            swipe(to: desktop)
        } else {
            pressShortcut(for: desktop)
        }
    }

    private func swipe(to desktop: Int) {
        guard let (from, to) = desktops.swipePositions(toDesktop: desktop) else {
            return Log.app.error("desktop \(desktop + 1) isn't on the active display")
        }
        if from != to, !DockSwipe.post(to > from ? .right : .left, steps: abs(to - from)) {
            Log.app.error("instant switch to desktop \(desktop + 1) failed")
        }
    }

    private func pressShortcut(for desktop: Int) {
        guard let (key, flags) = Self.shortcut(for: desktop) else {
            return Log.app.error("'Switch to Desktop \(desktop + 1)' has no enabled shortcut in System Settings")
        }
        let source = CGEventSource(stateID: .hidSystemState)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: keyDown)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
    }

    /// "Switch to Desktop 1...16" are symbolic hotkeys 118...133, each (character, key code, modifier flags).
    private static func shortcut(for desktop: Int) -> (CGKeyCode, CGEventFlags)? {
        guard (0..<SymbolicHotKey.desktopCount).contains(desktop),
            let hotKeys = UserDefaults(suiteName: SymbolicHotKey.domain)?.dictionary(forKey: SymbolicHotKey.key),
            let entry = hotKeys[String(SymbolicHotKey.firstDesktop + desktop)] as? [String: Any],
            (entry["enabled"] as? Bool) == true,
            let parameters = (entry["value"] as? [String: Any])?["parameters"] as? [Int],
            parameters.count == 3
        else { return nil }
        return (CGKeyCode(parameters[1]), CGEventFlags(rawValue: UInt64(parameters[2])))
    }

    /// Where macOS keeps its keyboard shortcuts, and which ones switch desktops.
    private enum SymbolicHotKey {
        static let domain = "com.apple.symbolichotkeys"
        static let key = "AppleSymbolicHotKeys"
        static let firstDesktop = 118
        static let desktopCount = 16
    }
}
