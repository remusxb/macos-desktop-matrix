import Carbon.HIToolbox
import Foundation
import Testing
@testable import WorkspaceMatrix

@Test func clampsAtEdges() {
    let grid = Grid(rows: 3, cols: 4, wrap: false)
    #expect(grid.move(from: 0, .up) == 0)
    #expect(grid.move(from: 0, .left) == 0)
    #expect(grid.move(from: 3, .right) == 3)
    #expect(grid.move(from: 11, .down) == 11)
    #expect(grid.move(from: 0, .down) == 4)
    #expect(grid.move(from: 5, .right) == 6)
}

@Test func wrapsAround() {
    let grid = Grid(rows: 3, cols: 4, wrap: true)
    #expect(grid.move(from: 0, .up) == 8)
    #expect(grid.move(from: 0, .left) == 3)
    #expect(grid.move(from: 11, .down) == 3)
    #expect(grid.move(from: 11, .right) == 8)
}

@Test func parsesCombos() {
    #expect(parseCombo("ctrl+cmd+up")! == (UInt32(kVK_UpArrow), UInt32(controlKey | cmdKey)))
    #expect(parseCombo("Shift + alt + Q")! == (UInt32(kVK_ANSI_Q), UInt32(shiftKey | optionKey)))
    #expect(parseCombo("hyper+q") == nil)
    #expect(parseCombo("cmd+") == nil)
    #expect(parseCombo("q") == nil)  // would block typing q everywhere
    #expect(parseCombo("shift+q") == nil)
}

@Test func recordsCombosParseCanRead() {
    #expect(comboString(keyCode: UInt16(kVK_UpArrow), modifiers: [.control, .command, .function]) == "ctrl+cmd+up")
    #expect(comboString(keyCode: UInt16(kVK_ANSI_K), modifiers: [.option, .shift]) == "alt+shift+k")
    #expect(comboString(keyCode: UInt16(kVK_ANSI_K), modifiers: [.shift]) == nil)
    #expect(comboString(keyCode: UInt16(kVK_Space), modifiers: [.command]) == nil)  // key not in the table
}

@Test func tilesFitOnScreen() {
    let screen = CGSize(width: 1600, height: 1000)
    #expect(tileSize(rows: 3, cols: 3, preferredWidth: 160, screen: screen) == CGSize(width: 160, height: 100))
    let huge = tileSize(rows: 8, cols: 10, preferredWidth: 400, screen: screen)
    #expect(huge.width * 10 < 1600 * 0.9)
    #expect(huge.height * 8 < 1000 * 0.9)
}

/// A Navigator wired to a fake macOS: records switches and lets the test fire pending timeouts.
private final class FakeDesktops {
    var desktop = 0
    var switches: [Int] = []
    var timeouts: [() -> Void] = []
    lazy var navigator = Navigator(switchTo: { self.switches.append($0) },
                                   currentDesktop: { self.desktop },
                                   after: { _, timeout in self.timeouts.append(timeout) })
}

@Test func coalescesPressesWhileSliding() {
    let mac = FakeDesktops()
    mac.navigator.request(1)
    mac.navigator.request(2)
    mac.navigator.request(3)
    #expect(mac.switches == [1])  // presses during the slide wait
    mac.desktop = 1
    #expect(!mac.navigator.arrived(at: 1))
    #expect(mac.switches == [1, 3])  // then one jump to the latest
    mac.desktop = 3
    #expect(mac.navigator.arrived(at: 3))
    #expect(!mac.navigator.isNavigating)
}

@Test func switchesFromElsewhereAreNotOurs() {
    let mac = FakeDesktops()
    #expect(!mac.navigator.isNavigating)  // a swipe: no grid
    #expect(mac.navigator.arrived(at: 4))
    mac.navigator.request(5)
    #expect(mac.navigator.isNavigating)  // our key: grid stays up until it lands
}

@Test func ignoresHopsOfAnInstantSwitch() {
    let mac = FakeDesktops()
    mac.navigator.request(3)
    #expect(!mac.navigator.arrived(at: 1))
    #expect(!mac.navigator.arrived(at: 2))
    #expect(mac.switches == [3])
    #expect(mac.navigator.arrived(at: 3))
}

@Test func retriesADroppedSwitchOnceThenGivesUp() {
    let mac = FakeDesktops()
    mac.navigator.request(2)
    mac.timeouts[0]()
    #expect(mac.switches == [2, 2])
    mac.timeouts[1]()
    #expect(mac.switches == [2, 2])
    #expect(mac.navigator.arrived(at: 0))  // a swipe afterwards just shows where you are
}

@Test func holdsSwitchesWhileCapturing() {
    let mac = FakeDesktops()
    mac.navigator.holding = true
    mac.navigator.request(1)
    #expect(mac.switches.isEmpty)
    mac.navigator.holding = false
    #expect(mac.switches == [1])
}

@Test func partialConfigKeepsDefaults() throws {
    let config = try JSONDecoder().decode(Config.self, from: Data(#"{"rows": 0, "cols": 5, "keys": {"up": "alt+k"}}"#.utf8))
    #expect(config.rows == 1)
    #expect(config.cols == 5)
    #expect(config.keys["up"] == "alt+k")
    #expect(config.keys["down"] == "ctrl+cmd+down")
}
