import Foundation

/// Turns "go to desktop N" requests into switches macOS actually completes. macOS ignores desktop
/// shortcuts pressed while it's still sliding, so requests made mid-switch are coalesced: once the
/// switch lands it jumps straight to the latest one, and the grid never runs ahead of the screen.
@MainActor
public final class Navigator {
    /// A switch that hasn't landed by then is retried, once.
    public static let retryAfter: Duration = .milliseconds(1500)
    private static let maxAttempts = 2

    private let switchTo: (Int) -> Void
    private let currentDesktop: () -> Int?
    private let after: (Duration, @escaping @MainActor () -> Void) -> Void
    private var requested: Int?
    private var posted: Int?
    private var attempts = 0
    private var generation = 0

    /// While true nothing is switched (a preview of the desktop being left is still being taken).
    public var holding = false {
        didSet { if !holding { drive() } }
    }

    /// True from a request until macOS lands on it (or it's given up).
    public var isNavigating: Bool { requested != nil || posted != nil }

    /// `after` runs a closure later; tests pass one they fire by hand.
    public init(
        switchTo: @escaping (Int) -> Void,
        currentDesktop: @escaping () -> Int?,
        after: @escaping (Duration, @escaping @MainActor () -> Void) -> Void = { delay, work in
            Task { @MainActor in
                try? await Task.sleep(for: delay)
                work()
            }
        }
    ) {
        self.switchTo = switchTo
        self.currentDesktop = currentDesktop
        self.after = after
    }

    /// Heads to `index`, replacing any earlier request that hasn't been switched to yet.
    public func request(_ index: Int) {
        requested = index
        attempts = 0
        drive()
    }

    /// macOS landed on `index`: true when that's where the user is heading, false for a stop on the way.
    public func arrived(at index: Int) -> Bool {
        // Instant switches hop one space at a time; only the posted target counts as landing.
        if let posted, index != posted { return false }
        posted = nil
        guard let requested else { return true }
        if index == requested {
            self.requested = nil
            return true
        }
        drive()  // more presses came in while macOS was switching
        return false
    }

    private func drive() {
        guard !holding, posted == nil, let target = requested else { return }
        if currentDesktop() == target {
            requested = nil
            return
        }
        posted = target
        attempts += 1
        generation += 1
        let current = generation
        switchTo(target)
        // macOS sometimes drops a switch entirely; retry rather than wait for an arrival forever.
        after(Self.retryAfter) { [weak self] in
            guard let self, self.generation == current, self.posted == target else { return }
            self.posted = nil
            if self.attempts >= Self.maxAttempts {
                Log.app.error("desktop \(target + 1) didn't come up, giving up")
                self.requested = nil
            } else {
                self.drive()
            }
        }
    }
}
