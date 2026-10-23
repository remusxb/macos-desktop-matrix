import Foundation

/// Turns "go to desktop N" requests into switches macOS actually completes. macOS ignores desktop
/// shortcuts pressed while it's still sliding, so requests made mid-switch are coalesced: once the
/// switch lands it jumps straight to the latest one, and the grid never runs ahead of the screen.
final class Navigator {
    private let switchTo: (Int) -> Void
    private let currentDesktop: () -> Int?
    private let after: (Double, @escaping () -> Void) -> Void
    private var requested: Int?
    private var posted: Int?
    private var attempts = 0
    private var generation = 0

    /// While true nothing is switched (a preview of the desktop being left is still being taken).
    var holding = false {
        didSet { if !holding { drive() } }
    }

    init(switchTo: @escaping (Int) -> Void,
         currentDesktop: @escaping () -> Int?,
         after: @escaping (Double, @escaping () -> Void) -> Void = {
             DispatchQueue.main.asyncAfter(deadline: .now() + $0, execute: $1)
         }) {
        self.switchTo = switchTo
        self.currentDesktop = currentDesktop
        self.after = after
    }

    /// True from a request until macOS lands on it (or gives up).
    var isNavigating: Bool { requested != nil || posted != nil }

    func request(_ index: Int) {
        requested = index
        attempts = 0
        drive()
    }

    /// macOS landed on `index`: true when that's where the user is heading, false for a stop on the way.
    func arrived(at index: Int) -> Bool {
        // Instant switches hop one desktop at a time; only the posted target counts as landing.
        if let posted, index != posted { return false }
        posted = nil
        guard let requested else { return true }
        if index == requested {
            self.requested = nil
            return true
        }
        drive()  // more presses came in while macOS was sliding
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
        // macOS sometimes drops a switch entirely; retry once rather than wait for an arrival forever.
        after(1.5) { [weak self] in
            guard let self, self.generation == current, self.posted == target else { return }
            self.posted = nil
            if self.attempts >= 2 {
                log("desktop \(target + 1) didn't come up, giving up")
                self.requested = nil
            } else {
                self.drive()
            }
        }
    }
}
