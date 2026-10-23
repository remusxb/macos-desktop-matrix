import AppKit

/// Keeps a window still while the desktops slide under it. A window on all desktops slides out and back in
/// with each one; a window in its own always-visible space above them doesn't move at all.
public enum DesktopPinning {
    /// The level of that space: above every desktop.
    private static let spaceLevel: Int32 = 100

    /// Moves `window` into its own space above the desktops; without SkyLight's calls it's left as it is.
    @MainActor
    public static func pinAboveDesktops(_ window: NSWindow) {
        guard let connection = SkyLight.mainConnectionID?(), let create = SkyLight.spaceCreate,
              let setLevel = SkyLight.spaceSetAbsoluteLevel, let show = SkyLight.showSpaces,
              let add = SkyLight.addWindowsToSpaces
        else { return }
        let space = create(connection, 1, nil)
        setLevel(connection, space, spaceLevel)
        show(connection, [space] as CFArray)
        add(connection, [window.windowNumber] as CFArray, [space] as CFArray)
    }
}
