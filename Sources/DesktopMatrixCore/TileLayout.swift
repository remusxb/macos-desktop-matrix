import CoreGraphics

/// The grid's geometry, shared by the view that draws it and the code that sizes its previews.
public enum TileLayout {
    /// Space between tiles, in points.
    public static let spacing: CGFloat = 10
    /// Space around the tiles inside the panel, in points.
    public static let padding: CGFloat = 16
    /// The grid never covers more of the screen than this, in either direction.
    public static let maxScreenFraction: CGFloat = 0.9

    /// `preferredWidth` wide and shaped like the screen, shrunk so the whole grid fits.
    public static func tileSize(rows: Int, cols: Int, preferredWidth: CGFloat, screen: CGSize) -> CGSize {
        let aspect = screen.height / screen.width
        let fitWidth = fitting(screen.width, CGFloat(cols))
        let fitHeight = fitting(screen.height, CGFloat(rows))
        let width = max(1, min(preferredWidth, fitWidth, fitHeight / aspect)).rounded(.down)
        return CGSize(width: width, height: (width * aspect).rounded(.down))
    }

    /// The largest tile length that lets `tiles` of them fit along `length` of screen.
    private static func fitting(_ length: CGFloat, _ tiles: CGFloat) -> CGFloat {
        (length * maxScreenFraction - 2 * padding - spacing * (tiles - 1)) / tiles
    }
}
