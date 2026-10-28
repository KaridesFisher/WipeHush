import Foundation

/// Pure session logic. Only the Escape key's press/release state is retained.
struct CleaningSession {
    static let escapeHoldDuration: TimeInterval = 2
    private(set) var deadline: TimeInterval?
    private var escapePressedAt: TimeInterval?

    var isActive: Bool { deadline != nil }

    mutating func start(duration: TimeInterval, now: TimeInterval) {
        deadline = now + min(max(duration, 1), 120)
        escapePressedAt = nil
    }

    mutating func escapeKey(isDown: Bool, now: TimeInterval) {
        guard isActive else { return }
        if isDown {
            // Autorepeated keyDown events must not restart the hold.
            if escapePressedAt == nil { escapePressedAt = now }
        } else {
            escapePressedAt = nil
        }
    }

    func escapeProgress(now: TimeInterval) -> Double {
        guard let pressed = escapePressedAt, isActive else { return 0 }
        return min(max((now - pressed) / Self.escapeHoldDuration, 0), 1)
    }

    func remainingSeconds(now: TimeInterval) -> Int {
        guard let deadline = deadline else { return 0 }
        return max(0, Int(ceil(deadline - now)))
    }

    func shouldStop(now: TimeInterval) -> Bool {
        guard let deadline = deadline else { return false }
        return now >= deadline || escapeProgress(now: now) >= 1
    }

    mutating func stop() {
        deadline = nil
        escapePressedAt = nil
    }
}
