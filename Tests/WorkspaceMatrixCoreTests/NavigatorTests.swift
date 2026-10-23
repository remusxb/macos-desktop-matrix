import Testing
import WorkspaceMatrixCore

/// A Navigator wired to a fake macOS: it records switches and lets the test fire pending retries.
@MainActor
private final class FakeMac {
    var desktop = 0
    var switches: [Int] = []
    var retries: [@MainActor () -> Void] = []
    lazy var navigator = Navigator(
        switchTo: { self.switches.append($0) },
        currentDesktop: { self.desktop },
        after: { _, retry in self.retries.append(retry) })
}

@MainActor @Test func coalescesPressesWhileSwitching() {
    let mac = FakeMac()
    mac.navigator.request(1)
    mac.navigator.request(2)
    mac.navigator.request(3)
    #expect(mac.switches == [1])  // presses during the switch wait...
    mac.desktop = 1
    #expect(!mac.navigator.arrived(at: 1))
    #expect(mac.switches == [1, 3])  // ...then one jump to the latest
    mac.desktop = 3
    #expect(mac.navigator.arrived(at: 3))
    #expect(!mac.navigator.isNavigating)
}

@MainActor @Test func switchesFromElsewhereAreNotOurs() {
    let mac = FakeMac()
    #expect(!mac.navigator.isNavigating)  // a swipe: no grid
    #expect(mac.navigator.arrived(at: 4))
    mac.navigator.request(5)
    #expect(mac.navigator.isNavigating)  // our key: the grid stays up until it lands
}

@MainActor @Test func ignoresTheHopsOfAnInstantSwitch() {
    let mac = FakeMac()
    mac.navigator.request(3)
    #expect(!mac.navigator.arrived(at: 1))
    #expect(!mac.navigator.arrived(at: 2))
    #expect(mac.switches == [3])
    #expect(mac.navigator.arrived(at: 3))
}

@MainActor @Test func retriesADroppedSwitchOnceThenGivesUp() {
    let mac = FakeMac()
    mac.navigator.request(2)
    mac.retries[0]()
    #expect(mac.switches == [2, 2])
    mac.retries[1]()
    #expect(mac.switches == [2, 2])
    #expect(mac.navigator.arrived(at: 0))  // a swipe afterwards just shows where you are
}

@MainActor @Test func holdsSwitchesWhileCapturing() {
    let mac = FakeMac()
    mac.navigator.holding = true
    mac.navigator.request(1)
    #expect(mac.switches.isEmpty)
    mac.navigator.holding = false
    #expect(mac.switches == [1])
}

@MainActor @Test func doesNothingWhenAlreadyThere() {
    let mac = FakeMac()
    mac.desktop = 2
    mac.navigator.request(2)
    #expect(mac.switches.isEmpty)
    #expect(!mac.navigator.isNavigating)
}
