/// A step on the grid.
public enum Direction: String, CaseIterable, Sendable {
    case up, down, left, right
}

/// Desktops laid out row by row: index 0 is the top-left tile, and macOS's Desktop N is index N - 1.
public struct Grid: Equatable, Sendable {
    /// At least 1.
    public let rows: Int
    /// At least 1.
    public let cols: Int
    /// Whether a step off an edge comes back in on the other side.
    public let wrap: Bool

    /// Rows and columns below 1 count as 1.
    public init(rows: Int, cols: Int, wrap: Bool) {
        self.rows = max(1, rows)
        self.cols = max(1, cols)
        self.wrap = wrap
    }

    /// How many tiles the grid has.
    public var count: Int { rows * cols }

    /// The tile one step from `index`; at an edge it wraps or stays put.
    public func move(from index: Int, _ direction: Direction) -> Int {
        var (row, col) = (index / cols, index % cols)
        switch direction {
        case .up: row -= 1
        case .down: row += 1
        case .left: col -= 1
        case .right: col += 1
        }
        if wrap {
            row = (row + rows) % rows
            col = (col + cols) % cols
        } else {
            row = min(max(row, 0), rows - 1)
            col = min(max(col, 0), cols - 1)
        }
        return row * cols + col
    }
}

/// Where macOS is: the current desktop (nil on a fullscreen app) and how many desktops there are.
public struct DesktopState: Equatable, Sendable {
    /// The current desktop's index, or nil while a fullscreen app has the screen.
    public var index: Int?
    /// The number of desktops on the display.
    public var count: Int

    /// A snapshot of where macOS is.
    public init(index: Int?, count: Int) {
        self.index = index
        self.count = count
    }
}
