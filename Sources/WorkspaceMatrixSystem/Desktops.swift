import CoreGraphics
import Foundation
import WorkspaceMatrixCore

/// The native macOS desktops on the display showing the active one: the same ones Mission Control and
/// trackpad swipes show. Read through SkyLight; nothing here changes anything.
public struct Desktops: Sendable {
    /// Reads the live state each time it's asked.
    public init() {}

    /// Where macOS is now.
    public func state() -> DesktopState {
        guard let display = activeDisplay() else { return DesktopState(index: nil, count: 0) }
        return DesktopState(index: display.desktops.firstIndex(of: display.active), count: display.desktops.count)
    }

    /// The desktops (by index) a window is on: empty for one on none, several for one on all of them.
    public func desktops(containing window: CGWindowID) -> [Int] {
        guard let display = activeDisplay(), let connection = SkyLight.mainConnectionID?(),
              let copy = SkyLight.copySpacesForWindows,
              let spaces = SkyLight.owned(copy(connection, SkyLight.allSpacesMask, [window] as CFArray), as: CFArray.self)
        else { return [] }
        return ((spaces as? [NSNumber]) ?? []).compactMap { display.desktops.firstIndex(of: $0.uint64Value) }
    }

    /// Where the active space and desktop `index` sit among every space of their display. Swipes step
    /// through fullscreen apps too, so they count here, unlike in desktop indexes.
    func swipePositions(toDesktop index: Int) -> (from: Int, to: Int)? {
        guard let display = activeDisplay(), display.desktops.indices.contains(index),
              let from = display.spaces.firstIndex(of: display.active),
              let to = display.spaces.firstIndex(of: display.desktops[index])
        else { return nil }
        return (from, to)
    }

    /// The active space, and the spaces of its display: all of them in order, and just the desktops.
    private func activeDisplay() -> (active: SkyLight.SpaceID, spaces: [SkyLight.SpaceID], desktops: [SkyLight.SpaceID])? {
        guard let connection = SkyLight.mainConnectionID?(), let active = SkyLight.getActiveSpace?(connection),
              let copy = SkyLight.copyManagedDisplaySpaces,
              let displays = SkyLight.owned(copy(connection), as: CFArray.self) as? [[String: Any]]
        else { return nil }
        for display in displays {
            let spaces = display[Key.spaces] as? [[String: Any]] ?? []
            let ids = spaces.compactMap(spaceID)
            guard ids.contains(active) else { continue }
            let desktops = spaces.filter { ($0[Key.type] as? Int) == Key.desktopType }.compactMap(spaceID)
            return (active, ids, desktops)
        }
        return nil
    }

    private func spaceID(_ space: [String: Any]) -> SkyLight.SpaceID? {
        (space[Key.spaceID] as? NSNumber)?.uint64Value
    }

    /// Names in SkyLight's display and space dictionaries.
    private enum Key {
        static let spaces = "Spaces"
        static let spaceID = "ManagedSpaceID"
        static let type = "type"
        /// A space's type for an ordinary desktop (fullscreen apps have others).
        static let desktopType = 0
    }
}
