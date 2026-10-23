enum Direction: String, CaseIterable {
    case up, down, left, right
}

/// Cells are numbered row by row: index 0 is top-left, native Desktop N is index + 1.
struct Grid {
    let rows: Int
    let cols: Int
    let wrap: Bool

    var count: Int { rows * cols }

    func move(from i: Int, _ direction: Direction) -> Int {
        var (r, c) = (i / cols, i % cols)
        switch direction {
        case .up: r -= 1
        case .down: r += 1
        case .left: c -= 1
        case .right: c += 1
        }
        if wrap {
            r = (r + rows) % rows
            c = (c + cols) % cols
        } else {
            r = min(max(r, 0), rows - 1)
            c = min(max(c, 0), cols - 1)
        }
        return r * cols + c
    }
}
