import CoreGraphics
import Foundation
import ISS
import Testing
@testable import WorkspaceMatrix

/// The Swift port must serialize exactly what InstantSpaceSwitcher's C does; the C is kept for this one commit.
@Test(arguments: [DockSwipe.Phase.began, .changed, .ended], [true, false])
func hidPayloadMatchesTheC(phase: DockSwipe.Phase, naturalScrolling: Bool) throws {
    for direction in [DockSwipe.Direction.left, .right] {
        let swipe = try #require(DockSwipe.modernSwipe(phase, direction, naturalScrolling: naturalScrolling))
        swipe.timestamp = 0x0123_4567_89AB_CDEF
        let fromC = try #require(iss_augment_dock_swipe_event(swipe)).takeRetainedValue()
        let fromSwift = try #require(DockSwipe.withHIDPayload(swipe))
        #expect(fromSwift.data as Data? == fromC.data as Data?)
    }
}

/// Fields the swipe doesn't set but the payload carries, so a non-default value must survive too.
@Test func hidPayloadMatchesTheCForEveryField() throws {
    let event = try #require(CGEvent(source: nil))
    event.timestamp = 42
    event.setIntegerValueField(DockSwipe.Field.phase, value: 4)
    event.setIntegerValueField(DockSwipe.Field.swipeMotion, value: 0x1_0002)  // truncated to 16 bits
    event.setIntegerValueField(DockSwipe.Field.swipeMask, value: 0x1_2345_6789)  // truncated to 32 bits
    event.setDoubleValueField(DockSwipe.Field.swipePositionX, value: -0.75)
    event.setDoubleValueField(DockSwipe.Field.swipePositionY, value: 1e-9)  // rounds to the smallest step, not 0
    event.setDoubleValueField(DockSwipe.Field.swipeProgress, value: 0.5)
    event.setDoubleValueField(DockSwipe.Field.swipeVelocityY, value: -1234.5)
    let fromC = try #require(iss_augment_dock_swipe_event(event)).takeRetainedValue()
    #expect(try #require(DockSwipe.withHIDPayload(event)).data as Data? == fromC.data as Data?)
}

@Test func fixedPointTruncatesLikeC() {
    #expect(DockSwipe.fixed1616(1) == 65536)
    #expect(DockSwipe.fixed1616(-1.5) == -98304)
    #expect(DockSwipe.fixed1616(1e-9) == 1)
    #expect(DockSwipe.fixed1616(-1e-9) == -1)
    #expect(DockSwipe.fixed1616(0) == 0)
}
