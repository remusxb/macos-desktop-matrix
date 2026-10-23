import AppKit
import SwiftUI
import WorkspaceMatrixCore

/// The grid HUD in the middle of the screen. It fades out `hideAfter` seconds after the last `show`.
@MainActor
public final class Overlay {
    private let panel: NSPanel
    private let model = OverlayModel()
    private var hideAfter: Double
    private var hideTask: Task<Void, Never>?

    /// False as soon as the fade-out starts, so the next key press reads the real desktop again.
    public private(set) var isShown = false
    /// The size, in pixels, previews should be captured at to be sharp in a tile.
    public private(set) var previewPixelSize = CGSize.zero

    /// `pin` keeps the panel still while the desktops slide under it.
    public init(rows: Int, cols: Int, tileWidth: Double, hideAfter: Double, pin: (NSWindow) -> Void) {
        self.hideAfter = hideAfter
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.ignoresMouseEvents = true
        panel.alphaValue = 0
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        configure(rows: rows, cols: cols, tileWidth: tileWidth, hideAfter: hideAfter)
        // Stays ordered in, invisible at alpha 0: ordering it out and in again could drop it from its pinned space.
        panel.orderFrontRegardless()
        pin(panel)
    }

    /// Rebuilds the grid for new settings; the panel, and the space it's pinned to, stay.
    public func configure(rows: Int, cols: Int, tileWidth: Double, hideAfter: Double) {
        self.hideAfter = hideAfter
        let screen = NSScreen.main
        let tile = TileLayout.tileSize(
            rows: rows, cols: cols, preferredWidth: tileWidth, screen: screen?.frame.size ?? Self.fallbackScreen)
        let scale = screen?.backingScaleFactor ?? 2
        previewPixelSize = CGSize(width: tile.width * scale, height: tile.height * scale)

        let hosting = NSHostingView(rootView: GridView(rows: rows, cols: cols, tile: tile, model: model))
        hosting.frame.size = hosting.fittingSize
        let background = NSVisualEffectView(frame: hosting.frame)
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.maskImage = .roundedMask(radius: Style.panelCornerRadius)
        background.addSubview(hosting)

        panel.setContentSize(hosting.frame.size)
        panel.contentView = background
        center()
    }

    /// Shows the grid with `desktop` highlighted, sliding the highlight there if the grid is already up.
    public func show(_ desktop: Int) {
        if isShown {
            withAnimation(.easeOut(duration: Style.highlightSlide)) { model.current = desktop }
        } else {
            isShown = true
            model.current = desktop
            center()
            NSAnimationContext.runAnimationGroup { $0.duration = Style.fadeIn; panel.animator().alphaValue = 1 }
        }
        hideTask?.cancel()
        hideTask = Task { [weak self, hideAfter] in
            try? await Task.sleep(for: .seconds(hideAfter))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    /// Sets a desktop's preview; with `onlyIfMissing`, a real screenshot already there wins.
    public func setPreview(_ desktop: Int, _ image: CGImage, onlyIfMissing: Bool = false) {
        if onlyIfMissing, model.previews[desktop] != nil { return }
        model.previews[desktop] = image
    }

    private func hide() {
        isShown = false
        NSAnimationContext.runAnimationGroup { $0.duration = Style.fadeOut; panel.animator().alphaValue = 0 }
    }

    private func center() {
        guard let frame = NSScreen.main?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.midY - panel.frame.height / 2))
    }

    private static let fallbackScreen = CGSize(width: 1600, height: 1000)
}

/// How the grid looks and moves.
enum Style {
    static let panelCornerRadius: CGFloat = 16
    static let tileCornerRadius: CGFloat = 8
    static let selectionWidth: CGFloat = 3
    static let fadeIn = 0.08
    static let fadeOut = 0.15
    static let highlightSlide = 0.1
}

/// What the grid shows: the highlighted desktop and the previews it has.
@MainActor
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
        VStack(spacing: TileLayout.spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: TileLayout.spacing) {
                    ForEach(0..<cols, id: \.self) { col in tileView(row * cols + col) }
                }
            }
        }
        .padding(TileLayout.padding)
    }

    private func tileView(_ desktop: Int) -> some View {
        let selected = desktop == model.current
        return ZStack {
            Group {
                if let preview = model.previews[desktop] {
                    Image(decorative: preview, scale: 1).resizable().opacity(selected ? 1 : 0.6)
                        .overlay(alignment: .topLeading) { numberBadge(desktop) }
                } else {
                    ZStack {
                        Color.white.opacity(0.08)
                        Text("\(desktop + 1)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(selected ? 1 : 0.55))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Style.tileCornerRadius))
            // The border lives outside the clip so it isn't cut off while sliding between tiles.
            if selected {
                RoundedRectangle(cornerRadius: Style.tileCornerRadius)
                    .strokeBorder(Color.accentColor, lineWidth: Style.selectionWidth)
                    .matchedGeometryEffect(id: "selection", in: namespace)
            }
        }
        .frame(width: tile.width, height: tile.height)
    }

    /// The desktop's number over its preview, readable on any picture.
    private func numberBadge(_ desktop: Int) -> some View {
        Text("\(desktop + 1)")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.black.opacity(0.6), in: Capsule())
            .padding(6)
    }
}

extension NSImage {
    /// NSVisualEffectView ignores layer.cornerRadius for its blur; a stretchable mask is the supported way.
    fileprivate static func roundedMask(radius: CGFloat) -> NSImage {
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
