import CoreGraphics
import DesktopMatrixCore
@preconcurrency import ScreenCaptureKit

/// Desktop previews: screenshots of the main display, minus the app's own grid, and Mission Control–style
/// previews composed from each desktop's windows. Needs Screen Recording; without it every call returns
/// nothing and tiles show their number instead. Images stay in memory.
@MainActor
public final class ScreenCapture {
    private let desktops: Desktops
    private var filter: SCContentFilter?

    /// Previews of `desktops`.
    public init(desktops: Desktops) {
        self.desktops = desktops
    }

    /// The screen as it looks now, `size` pixels.
    public func capture(size: CGSize) async -> CGImage? {
        guard CGPreflightScreenCaptureAccess() else { return nil }
        do {
            if filter == nil { filter = try await makeFilter() }
            guard let filter else { return nil }
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration(size))
        } catch {
            filter = nil  // displays may have changed; rebuild on the next capture
            Log.app.error("screen capture failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// A preview of every desktop without visiting any: the wallpaper with each desktop's windows drawn back
    /// to front where they sit, `size` pixels each, keyed by desktop index.
    public func composeAll(size: CGSize) async -> [Int: CGImage] {
        guard CGPreflightScreenCaptureAccess() else { return [:] }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) else { return [:] }
            let scale = size.width / display.frame.width
            let wallpaper = await wallpaper(content, display, size)
            let windows = windowsByDesktop(content)
            var previews: [Int: CGImage] = [:]
            for desktop in 0..<desktops.state().count {
                previews[desktop] = await compose(windows[desktop] ?? [], over: wallpaper, display, scale, size)
            }
            return previews
        } catch {
            Log.app.error("composing previews failed: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }

    /// The wallpaper sits a few windows below the desktop icons (owned by Wallpaper, WindowManager...).
    private func wallpaper(_ content: SCShareableContent, _ display: SCDisplay, _ size: CGSize) async -> CGImage? {
        let iconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
        let windows = content.windows.filter { $0.windowLayer < iconLevel }
        guard !windows.isEmpty else { return nil }
        let filter = SCContentFilter(display: display, including: windows)
        return try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration(size))
    }

    /// Ordinary windows on exactly one desktop, back to front.
    private func windowsByDesktop(_ content: SCShareableContent) -> [Int: [SCWindow]] {
        let order = (CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? [])
            .compactMap { $0[kCGWindowNumber as String] as? CGWindowID }
        let depth = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        var byDesktop: [Int: [SCWindow]] = [:]
        for window in content.windows
        where window.windowLayer == 0 && window.frame.width >= Self.minimumWindowSide
            && window.frame.height >= Self.minimumWindowSide
        {
            let desktops = desktops.desktops(containing: window.windowID)
            guard desktops.count == 1 else { continue }  // on no desktop, or on all of them
            byDesktop[desktops[0], default: []].append(window)
        }
        return byDesktop.mapValues { windows in
            windows.sorted { depth[$0.windowID, default: .max] > depth[$1.windowID, default: .max] }
        }
    }

    private func compose(
        _ windows: [SCWindow], over wallpaper: CGImage?, _ display: SCDisplay, _ scale: CGFloat, _ size: CGSize
    ) async -> CGImage? {
        guard
            let context = CGContext(
                data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        else { return nil }
        if let wallpaper { context.draw(wallpaper, in: CGRect(origin: .zero, size: size)) }
        for window in windows {
            let frame = window.frame  // top-left origin, like the screen; the context's is bottom-left
            let rect = CGRect(
                x: frame.minX * scale, y: (display.frame.height - frame.maxY) * scale,
                width: frame.width * scale, height: frame.height * scale)
            let filter = SCContentFilter(desktopIndependentWindow: window)
            guard
                let image = try? await SCScreenshotManager.captureImage(
                    contentFilter: filter, configuration: configuration(rect.size))
            else { continue }
            context.draw(image, in: rect)
        }
        return context.makeImage()
    }

    private func configuration(_ size: CGSize) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(size.width))
        configuration.height = max(1, Int(size.height))
        configuration.showsCursor = false
        return configuration
    }

    /// The main display without the app's own windows, so the grid isn't in its own previews.
    private func makeFilter() async throws -> SCContentFilter? {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) else { return nil }
        let me = content.applications.filter { $0.processID == getpid() }
        return SCContentFilter(display: display, excludingApplications: me, exceptingWindows: [])
    }

    /// Smaller windows (popovers, palettes) aren't worth drawing in a preview.
    private static let minimumWindowSide: CGFloat = 100
}
