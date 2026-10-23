import AppKit
import SwiftUI

private let gridSpacing: CGFloat = 10
private let gridPadding: CGFloat = 16

/// `preferredWidth` wide and screen-shaped, but shrunk so the whole grid fits in 90% of the screen.
func tileSize(rows: Int, cols: Int, preferredWidth: CGFloat, screen: CGSize) -> CGSize {
    let aspect = screen.height / screen.width
    let fitWidth = (screen.width * 0.9 - 2 * gridPadding - gridSpacing * CGFloat(cols - 1)) / CGFloat(cols)
    let fitHeight = (screen.height * 0.9 - 2 * gridPadding - gridSpacing * CGFloat(rows - 1)) / CGFloat(rows)
    let width = max(1, min(preferredWidth, fitWidth, fitHeight / aspect)).rounded(.down)
    return CGSize(width: width, height: (width * aspect).rounded(.down))
}

final class OverlayModel: ObservableObject {
    @Published var current = 0
    @Published var previews: [Int: CGImage] = [:]
}

struct GridView: View {
    let rows: Int
    let cols: Int
    let tile: CGSize
    @ObservedObject var model: OverlayModel
    @Namespace private var namespace

    var body: some View {
        VStack(spacing: gridSpacing) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: gridSpacing) {
                    ForEach(0..<cols, id: \.self) { c in tileView(r * cols + c) }
                }
            }
        }
        .padding(gridPadding)
    }

    private func tileView(_ i: Int) -> some View {
        let selected = i == model.current
        return ZStack {
            Group {
                if let preview = model.previews[i] {
                    Image(decorative: preview, scale: 1).resizable().opacity(selected ? 1 : 0.6)
                        .overlay(alignment: .topLeading) {
                            Text("\(i + 1)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.6), in: Capsule())
                                .padding(6)
                        }
                } else {
                    ZStack {
                        Color.white.opacity(0.08)
                        Text("\(i + 1)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(selected ? 1 : 0.55))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            // The border lives outside the clip so it isn't cut off while sliding between tiles.
            if selected {
                RoundedRectangle(cornerRadius: 8).strokeBorder(Color.accentColor, lineWidth: 3)
                    .matchedGeometryEffect(id: "selection", in: namespace)
            }
        }
        .frame(width: tile.width, height: tile.height)
    }
}

/// HUD panel in the middle of the screen; fades out `hideAfter` seconds after the last move.
final class Overlay {
    private let panel: NSPanel
    private let model = OverlayModel()
    var hideAfter: Double
    private var hideTask: DispatchWorkItem?
    /// False as soon as the fade-out starts, so a new key press resyncs with the real desktop.
    private(set) var isShown = false
    /// Pixel size previews should be captured at, so they're sharp on Retina.
    private(set) var previewPixelSize = CGSize.zero

    init(rows: Int, cols: Int, tileWidth: CGFloat, hideAfter: Double) {
        self.hideAfter = hideAfter
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.ignoresMouseEvents = true
        panel.alphaValue = 0
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        configure(rows: rows, cols: cols, tileWidth: tileWidth)
        // Stays ordered in, invisible at alpha 0: re-ordering it could drop it from its pinned space.
        panel.orderFrontRegardless()
        pinAboveDesktops(panel)
    }

    /// Rebuilds the grid for a new size; the panel and its pinned space stay.
    func configure(rows: Int, cols: Int, tileWidth: CGFloat) {
        let screen = NSScreen.main
        let tile = tileSize(rows: rows, cols: cols, preferredWidth: tileWidth,
                            screen: screen?.frame.size ?? CGSize(width: 1600, height: 1000))
        let scale = screen?.backingScaleFactor ?? 2
        previewPixelSize = CGSize(width: tile.width * scale, height: tile.height * scale)

        let hosting = NSHostingView(rootView: GridView(rows: rows, cols: cols, tile: tile, model: model))
        hosting.frame.size = hosting.fittingSize

        let background = NSVisualEffectView(frame: hosting.frame)
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.maskImage = .roundedMask(radius: 16)
        background.addSubview(hosting)

        panel.setContentSize(hosting.frame.size)
        panel.contentView = background
        center()
    }

    private func center() {
        guard let frame = NSScreen.main?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.midY - panel.frame.height / 2))
    }

    func setPreview(_ index: Int, _ image: CGImage, onlyIfMissing: Bool = false) {
        if onlyIfMissing, model.previews[index] != nil { return }
        model.previews[index] = image
    }

    func show(_ current: Int) {
        if isShown {
            withAnimation(.easeOut(duration: 0.1)) { model.current = current }
        } else {
            isShown = true
            model.current = current
            center()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.08; panel.animator().alphaValue = 1 }
        }
        hideTask?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.hide() }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + hideAfter, execute: task)
    }

    private func hide() {
        isShown = false
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; panel.animator().alphaValue = 0 }
    }
}

/// Moves the window into its own always-visible space above the desktops, so it stays still while they
/// slide (a window on all desktops slides out and back in with each one). Private SkyLight calls, looked
/// up at runtime: if one is missing the window just slides along.
private func pinAboveDesktops(_ window: NSWindow) {
    let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    func load<T>(_ name: String, as _: T.Type) -> T? { dlsym(skyLight, name).map { unsafeBitCast($0, to: T.self) } }
    guard let mainConnection = load("SLSMainConnectionID", as: (@convention(c) () -> Int32).self),
          let createSpace = load("SLSSpaceCreate", as: (@convention(c) (Int32, Int32, CFDictionary?) -> UInt64).self),
          let setLevel = load("SLSSpaceSetAbsoluteLevel", as: (@convention(c) (Int32, UInt64, Int32) -> Void).self),
          let showSpaces = load("SLSShowSpaces", as: (@convention(c) (Int32, CFArray) -> Void).self),
          let addWindows = load("SLSAddWindowsToSpaces", as: (@convention(c) (Int32, CFArray, CFArray) -> Void).self)
    else { return log("SkyLight space calls missing: the overlay will slide with the desktops") }
    let connection = mainConnection()
    let space = createSpace(connection, 1, nil)
    setLevel(connection, space, 100)
    showSpaces(connection, [space] as CFArray)
    addWindows(connection, [window.windowNumber] as CFArray, [space] as CFArray)
}

private extension NSImage {
    // NSVisualEffectView ignores layer.cornerRadius for the blur; a stretchable mask is the supported way.
    static func roundedMask(radius: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: radius * 2 + 1, height: radius * 2 + 1), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
