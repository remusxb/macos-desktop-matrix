import ScreenCaptureKit

/// Screenshots of the main display, minus our own overlay, used as workspace previews.
/// Needs Screen Recording permission; without it captures return nil and tiles show their number.
final class ScreenCapture {
    private var filter: SCContentFilter?

    init() {
        if !CGPreflightScreenCaptureAccess() {
            log("no Screen Recording permission yet: previews are off until it's granted and the app restarts")
            CGRequestScreenCaptureAccess()
        }
    }

    func capture(size: CGSize) async -> CGImage? {
        guard CGPreflightScreenCaptureAccess() else { return nil }
        do {
            if filter == nil { filter = try await makeFilter() }
            guard let filter else { return nil }
            let config = SCStreamConfiguration()
            config.width = Int(size.width)
            config.height = Int(size.height)
            config.showsCursor = false
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            filter = nil  // displays may have changed; rebuild on the next capture
            log("screen capture failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Mission Control–style previews of every desktop without visiting them: the wallpaper with each
    /// desktop's windows drawn back to front where they sit. `size` is in pixels.
    func composePreviews(size: CGSize) async -> [Int: CGImage] {
        guard CGPreflightScreenCaptureAccess() else { return [:] }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) else { return [:] }
            let screen = display.frame.size
            let scale = size.width / screen.width

            // The wallpaper is a few windows below the desktop icons (owned by Wallpaper, WindowManager...).
            let iconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
            let wallpaperWindows = content.windows.filter { $0.windowLayer < iconLevel }
            let wallpaper = wallpaperWindows.isEmpty ? nil : try? await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(display: display, including: wallpaperWindows),
                configuration: configuration(size))

            // Every window front to back, so each desktop can be painted back to front.
            let order = (CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? [])
                .compactMap { $0[kCGWindowNumber as String] as? CGWindowID }
            let depth = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })

            var windowsByDesktop: [Int: [SCWindow]] = [:]
            for window in content.windows where window.windowLayer == 0 && window.frame.width >= 100 && window.frame.height >= 100 {
                let desktops = Desktops.desktops(containing: window.windowID)
                guard desktops.count == 1 else { continue }  // skip windows on no desktop or on all of them
                windowsByDesktop[desktops[0], default: []].append(window)
            }

            var previews: [Int: CGImage] = [:]
            for desktop in 0..<Desktops.state().count {
                guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                              bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { continue }
                if let wallpaper { context.draw(wallpaper, in: CGRect(origin: .zero, size: size)) }
                let windows = (windowsByDesktop[desktop] ?? []).sorted { depth[$0.windowID, default: .max] > depth[$1.windowID, default: .max] }
                for window in windows {
                    let frame = window.frame
                    let rect = CGRect(x: frame.minX * scale, y: (screen.height - frame.maxY) * scale,
                                      width: frame.width * scale, height: frame.height * scale)
                    guard let image = try? await SCScreenshotManager.captureImage(
                        contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: configuration(rect.size))
                    else { continue }
                    context.draw(image, in: rect)
                }
                previews[desktop] = context.makeImage()
            }
            return previews
        } catch {
            log("composing previews failed: \(error.localizedDescription)")
            return [:]
        }
    }

    private func configuration(_ size: CGSize) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = max(1, Int(size.width))
        config.height = max(1, Int(size.height))
        config.showsCursor = false
        return config
    }

    private func makeFilter() async throws -> SCContentFilter? {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) else { return nil }
        let me = content.applications.filter { $0.processID == getpid() }
        return SCContentFilter(display: display, excludingApplications: me, exceptingWindows: [])
    }
}
