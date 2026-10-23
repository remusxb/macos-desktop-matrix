import AppKit
import ISS

// Private but read-only SkyLight calls (as used by Spaces indicator apps); they need no SIP changes.
@_silgen_name("CGSMainConnectionID") private func CGSMainConnectionID() -> Int32
@_silgen_name("CGSGetActiveSpace") private func CGSGetActiveSpace(_ connection: Int32) -> UInt64
@_silgen_name("CGSCopyManagedDisplaySpaces") private func CGSCopyManagedDisplaySpaces(_ connection: Int32) -> CFArray
@_silgen_name("CGSCopySpacesForWindows") private func CGSCopySpacesForWindows(_ connection: Int32, _ mask: Int32, _ windows: CFArray) -> CFArray

/// Native macOS desktops: the same ones Mission Control and trackpad swipes show.
enum Desktops {
    /// The current desktop (nil on a fullscreen app) and how many desktops its display has.
    static func state() -> (index: Int?, count: Int) {
        let connection = CGSMainConnectionID()
        let active = CGSGetActiveSpace(connection)
        let desktops = activeDisplayDesktops(connection, active)
        return (desktops.firstIndex(of: active), desktops.count)
    }

    /// The desktops (by index) a window is on; empty for windows on none, several for ones on all.
    static func desktops(containing window: CGWindowID) -> [Int] {
        let connection = CGSMainConnectionID()
        let desktops = activeDisplayDesktops(connection, CGSGetActiveSpace(connection))
        let allSpaces: Int32 = 7
        let spaces = CGSCopySpacesForWindows(connection, allSpaces, [window] as CFArray) as? [NSNumber] ?? []
        return spaces.compactMap { desktops.firstIndex(of: $0.uint64Value) }
    }

    /// Space IDs of the desktops (not fullscreen apps) on the display showing `active`.
    private static func activeDisplayDesktops(_ connection: Int32, _ active: UInt64) -> [UInt64?] {
        let displays = CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] ?? []
        for display in displays {
            let spaces = display["Spaces"] as? [[String: Any]] ?? []
            guard spaces.contains(where: { spaceID($0) == active }) else { continue }
            return spaces.filter { ($0["type"] as? Int) == 0 }.map(spaceID)
        }
        return []
    }

    /// Normal: presses the "Switch to Desktop N" shortcut set in System Settings, so macOS slides there itself.
    /// Instant: posts trackpad swipes so fast that macOS skips the slide.
    static func switchTo(_ index: Int, instant: Bool) {
        if instant {
            if !iss_switch_to_index(UInt32(index)) { log("instant switch to desktop \(index + 1) failed") }
            return
        }
        guard let (key, flags) = shortcut(index) else {
            return log("'Switch to Desktop \(index + 1)' has no enabled shortcut in System Settings")
        }
        let source = CGEventSource(stateID: .hidSystemState)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: keyDown)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
    }

    private static func spaceID(_ space: [String: Any]) -> UInt64? {
        (space["ManagedSpaceID"] as? NSNumber)?.uint64Value
    }

    // "Switch to Desktop 1...16" are symbolic hotkeys 118...133: (character, key code, modifier flags).
    private static func shortcut(_ index: Int) -> (CGKeyCode, CGEventFlags)? {
        guard index < 16,
              let hotKeys = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys"),
              let entry = hotKeys[String(118 + index)] as? [String: Any],
              (entry["enabled"] as? Bool) == true,
              let parameters = (entry["value"] as? [String: Any])?["parameters"] as? [Int],
              parameters.count == 3
        else { return nil }
        return (CGKeyCode(parameters[1]), CGEventFlags(rawValue: UInt64(parameters[2])))
    }
}
