import CoreGraphics
import Foundation
import Testing

@testable import DesktopMatrixSystem

/// Payloads InstantSpaceSwitcher's C produced for these swipes (captured when the port was checked against it
/// byte for byte). They're reviewed data: a change here changes what the Dock receives.
private let golden: [(DockSwipe.Phase, DockSwipe.Direction, String)] = [
    (
        .began, .right,
        """
        efcdab89674523010000000000000000000000000000000001000000280000001700000000000001000000009919000000000000\
        000000000000000001000300ffffffff
        """
    ),
    (
        .ended, .left,
        """
        efcdab89674523010000000000000000000000000000000002000000280000001700000000000004000000009919000000000000\
        000000000000000001000300010000001c00000009000000000000000100000000000f270000000000000000
        """
    ),
]

@Test func hidPayloadMatchesTheGoldenBytes() throws {
    for (phase, direction, hex) in golden {
        let swipe = try #require(DockSwipe.modernSwipe(phase, direction, naturalScrolling: true))
        swipe.timestamp = 0x0123_4567_89AB_CDEF
        let bytes = DockSwipe.hidPayload(swipe).map { String(format: "%02x", $0) }.joined()
        #expect(bytes == hex, "\(phase) \(direction)")
    }
}

@Test func naturalScrollingFlipsTheSign() throws {
    let natural = try #require(DockSwipe.modernSwipe(.ended, .right, naturalScrolling: true))
    let classic = try #require(DockSwipe.modernSwipe(.ended, .right, naturalScrolling: false))
    #expect(natural.getDoubleValueField(DockSwipe.Field.swipeVelocityX) < 0)  // on macOS 27 right is negative
    #expect(classic.getDoubleValueField(DockSwipe.Field.swipeVelocityX) > 0)
}

@Test func onlyTheEndedPhaseFlings() throws {
    for phase in [DockSwipe.Phase.began, .changed] {
        let swipe = try #require(DockSwipe.modernSwipe(phase, .left, naturalScrolling: true))
        #expect(swipe.getDoubleValueField(DockSwipe.Field.swipeVelocityX) == 0)
    }
}

@Test func fixedPointTruncatesLikeC() {
    #expect(DockSwipe.fixed1616(1) == 65536)
    #expect(DockSwipe.fixed1616(-1.5) == -98304)
    #expect(DockSwipe.fixed1616(1e-9) == 1)
    #expect(DockSwipe.fixed1616(-1e-9) == -1)
    #expect(DockSwipe.fixed1616(0) == 0)
    #expect(DockSwipe.fixed1616(1e12) == Int32.max)  // clamped where C would be undefined
}
