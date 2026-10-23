import CoreGraphics
import Testing
import WorkspaceMatrixCore

@Test func stepsStopAtTheEdges() {
    let grid = Grid(rows: 3, cols: 4, wrap: false)
    #expect(grid.move(from: 0, .up) == 0)
    #expect(grid.move(from: 0, .left) == 0)
    #expect(grid.move(from: 3, .right) == 3)
    #expect(grid.move(from: 11, .down) == 11)
    #expect(grid.move(from: 0, .down) == 4)
    #expect(grid.move(from: 5, .right) == 6)
}

@Test func stepsWrapAroundWhenAsked() {
    let grid = Grid(rows: 3, cols: 4, wrap: true)
    #expect(grid.move(from: 0, .up) == 8)
    #expect(grid.move(from: 0, .left) == 3)
    #expect(grid.move(from: 11, .down) == 3)
    #expect(grid.move(from: 11, .right) == 8)
}

@Test func aGridHasAtLeastOneTile() {
    let grid = Grid(rows: 0, cols: -2, wrap: false)
    #expect(grid.count == 1)
    #expect(grid.move(from: 0, .right) == 0)
}

@Test func tilesFitOnTheScreen() {
    let screen = CGSize(width: 1600, height: 1000)
    #expect(
        TileLayout.tileSize(rows: 3, cols: 3, preferredWidth: 160, screen: screen) == CGSize(width: 160, height: 100))
    let huge = TileLayout.tileSize(rows: 8, cols: 10, preferredWidth: 400, screen: screen)
    #expect(huge.width * 10 < screen.width * TileLayout.maxScreenFraction)
    #expect(huge.height * 8 < screen.height * TileLayout.maxScreenFraction)
}
