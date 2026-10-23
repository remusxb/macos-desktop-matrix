import CoreGraphics
import Foundation

/// Instant desktop switching: a synthetic trackpad swipe so fast that the Dock skips its slide.
/// Ported from InstantSpaceSwitcher by jurplel (MIT): https://github.com/jurplel/InstantSpaceSwitcher
enum DockSwipe {
    enum Direction {
        case left, right
    }

    enum Phase: Int64 {
        case began = 1
        case changed = 2
        case ended = 4
    }

    /// Swipes `steps` spaces toward `direction`; false if an event couldn't be built.
    static func post(_ direction: Direction, steps: Int) -> Bool {
        let needsHIDPayload = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
        let natural = naturalScrolling()
        for _ in 0..<steps {
            // Began, changed and ended: with only two, Mission Control stops working.
            for phase in [Phase.began, .changed, .ended] {
                let events = needsHIDPayload
                    ? modernEvents(phase, direction, naturalScrolling: natural)
                    : legacyEvents(phase, direction, velocity: legacyVelocityPerStep * Double(steps))
                guard let events else { return false }
                events.forEach { $0.post(tap: .cgSessionEventTap) }
            }
        }
        return true
    }

    /// The swipe macOS 27 honours: the public gesture fields plus the raw IOHID gesture a trackpad sends.
    static func modernEvents(_ phase: Phase, _ direction: Direction, naturalScrolling: Bool) -> [CGEvent]? {
        guard let swipe = modernSwipe(phase, direction, naturalScrolling: naturalScrolling),
              let augmented = withHIDPayload(swipe),
              let companion = CGEvent(source: nil)
        else { return nil }
        // The Dock ignores a dock-control event without a gesture event alongside it.
        companion.setIntegerValueField(Field.eventType, value: EventType.gesture)
        return [augmented, companion]
    }

    /// The public gesture fields of a macOS 27 swipe, before the IOHID payload is added.
    static func modernSwipe(_ phase: Phase, _ direction: Direction, naturalScrolling: Bool) -> CGEvent? {
        // A swipe right is negative, and the Dock reads the sign through the natural scrolling setting.
        let sign: Double = (direction == .right ? -1 : 1) * (naturalScrolling ? 1 : -1)
        guard let swipe = CGEvent(source: nil) else { return nil }
        swipe.setIntegerValueField(Field.eventType, value: EventType.dockControl)
        swipe.setIntegerValueField(Field.gestureHIDType, value: hidDockSwipe)
        swipe.setIntegerValueField(Field.phase, value: phase.rawValue)
        swipe.setIntegerValueField(Field.swipeMotion, value: motionHorizontal)
        // The smallest non-zero 16.16 progress leaves nothing to animate; a full one flashes the old space.
        swipe.setDoubleValueField(Field.swipeProgress, value: sign * minimalProgress)
        // Fields a real trackpad swipe carries.
        swipe.setIntegerValueField(Field.phaseAlias, value: phase.rawValue)
        swipe.setDoubleValueField(Field.zoomDeltaY, value: 3)
        swipe.setDoubleValueField(Field.sourcePIDAlias, value: Double(mach_absolute_time()))
        swipe.setDoubleValueField(Field.swipePositionX, value: 0.1)
        // Only the ended phase carries the fling that commits the switch.
        if phase == .ended {
            swipe.setDoubleValueField(Field.swipeVelocityX, value: sign * modernFlingVelocity)
        }
        return swipe
    }

    /// Before macOS 27 the public fields are enough, and the velocity sets how fast the slide goes.
    static func legacyEvents(_ phase: Phase, _ direction: Direction, velocity: Double) -> [CGEvent]? {
        let sign: Double = direction == .right ? 1 : -1
        guard let swipe = CGEvent(source: nil) else { return nil }
        swipe.setIntegerValueField(Field.eventType, value: EventType.dockControl)
        swipe.setIntegerValueField(Field.gestureHIDType, value: hidDockSwipe)
        swipe.setIntegerValueField(Field.phase, value: phase.rawValue)
        swipe.setDoubleValueField(Field.swipeProgress, value: sign * minimalProgress)
        swipe.setIntegerValueField(Field.swipeMotion, value: motionHorizontal)
        swipe.setDoubleValueField(Field.swipeVelocityX, value: sign * velocity)
        swipe.setDoubleValueField(Field.swipeVelocityY, value: sign * velocity)
        return [swipe]
    }

    /// Appends the raw IOHID gesture to the event's serialized form (format version 2 only).
    static func withHIDPayload(_ event: CGEvent) -> CGEvent? {
        guard let serialized = event.data as Data?, serialized.prefix(4) == Data([0, 0, 0, 2]) else { return nil }
        let payload = hidPayload(event)
        var data = serialized
        // A big-endian tag: the payload's size, then the field id it's stored under.
        for word in [UInt16(payload.count), hidPayloadFieldID] {
            data.append(contentsOf: [UInt8(word >> 8), UInt8(word & 0xFF)])
        }
        data.append(payload)
        return CGEvent(withDataAllocator: nil, data: data as CFData)
    }

    /// An IOHID system-queue element: a header, a fluid touch gesture and, when it moves, a velocity event.
    static func hidPayload(_ event: CGEvent) -> Data {
        let phase = event.getIntegerValueField(Field.phase)
        let velocityX = event.getDoubleValueField(Field.swipeVelocityX)
        let velocityY = event.getDoubleValueField(Field.swipeVelocityY)
        let hasVelocity = velocityX != 0 || velocityY != 0 || phase == Phase.ended.rawValue
        var data = Data()

        data.appendLittleEndian(event.timestamp != 0 ? event.timestamp : mach_absolute_time())
        data.appendLittleEndian(UInt64(0))  // sender id
        data.appendLittleEndian(UInt32(0))  // options
        data.appendLittleEndian(UInt32(0))  // attribute length
        data.appendLittleEndian(UInt32(hasVelocity ? 2 : 1))  // event count

        data.appendHIDEventBase(size: 40, type: hidFluidTouchGesture, options: UInt32(truncatingIfNeeded: (phase & 0xFF) << 24), depth: 0)
        data.appendLittleEndian(fixed1616(event.getDoubleValueField(Field.swipePositionX)))
        data.appendLittleEndian(fixed1616(event.getDoubleValueField(Field.swipePositionY)))
        data.appendLittleEndian(Int32(0))  // position z
        data.appendLittleEndian(UInt32(truncatingIfNeeded: event.getIntegerValueField(Field.swipeMask)))
        data.appendLittleEndian(UInt16(truncatingIfNeeded: event.getIntegerValueField(Field.swipeMotion)))
        data.appendLittleEndian(hidGestureFlavorDockPrimary)
        data.appendLittleEndian(fixed1616(event.getDoubleValueField(Field.swipeProgress)))

        if hasVelocity {
            data.appendHIDEventBase(size: 28, type: hidVelocity, options: 0, depth: 1)
            data.appendLittleEndian(fixed1616(velocityX))
            data.appendLittleEndian(fixed1616(velocityY))
            data.appendLittleEndian(Int32(0))  // velocity z
        }
        return data
    }

    /// 16.16 fixed point, truncated like a C cast; a non-zero value never rounds to zero.
    static func fixed1616(_ value: Double) -> Int32 {
        let fixed = Int32(max(min(value * 65536, Double(Int32.max)), Double(Int32.min)))
        if fixed == 0 && value != 0 { return value > 0 ? 1 : -1 }
        return fixed
    }

    private static func naturalScrolling() -> Bool {
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)  // pick up a change made while we run
        var valid: DarwinBoolean = false
        let natural = CFPreferencesGetAppBooleanValue("com.apple.swipescrolldirection" as CFString,
                                                      kCFPreferencesAnyApplication, &valid)
        return natural || !valid.boolValue  // unset means the macOS default, natural
    }

    private static let minimalProgress = 0.000016
    private static let modernFlingVelocity = 9999.0
    private static let legacyVelocityPerStep = 2000.0
    private static let motionHorizontal: Int64 = 1
    private static let hidDockSwipe: Int64 = 23
    private static let hidFluidTouchGesture: UInt32 = 23
    private static let hidVelocity: UInt32 = 9
    private static let hidGestureFlavorDockPrimary: UInt16 = 3
    private static let hidPayloadFieldID: UInt16 = 4205

    private enum EventType {
        static let gesture: Int64 = 29
        static let dockControl: Int64 = 30
    }

    /// Undocumented CGEvent fields of gesture events.
    enum Field {
        static let eventType = CGEventField(rawValue: 55)!
        static let gestureHIDType = CGEventField(rawValue: 110)!
        static let swipeMask = CGEventField(rawValue: 115)!
        static let swipeMotion = CGEventField(rawValue: 123)!
        static let swipeProgress = CGEventField(rawValue: 124)!
        static let swipePositionX = CGEventField(rawValue: 125)!
        static let swipePositionY = CGEventField(rawValue: 126)!
        static let swipeVelocityX = CGEventField(rawValue: 129)!
        static let swipeVelocityY = CGEventField(rawValue: 130)!
        static let phase = CGEventField(rawValue: 132)!
        static let phaseAlias = CGEventField(rawValue: 134)!
        static let zoomDeltaY = CGEventField(rawValue: 138)!
        static let sourcePIDAlias = CGEventField(rawValue: 169)!
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    /// The 16-byte header every IOHID event starts with: size, type, options, depth and 3 reserved bytes.
    mutating func appendHIDEventBase(size: UInt32, type: UInt32, options: UInt32, depth: UInt8) {
        appendLittleEndian(size)
        appendLittleEndian(type)
        appendLittleEndian(options)
        append(contentsOf: [depth, 0, 0, 0])
    }
}
