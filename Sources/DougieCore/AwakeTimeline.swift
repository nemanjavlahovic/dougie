import Foundation

/// The session's clock, shared by the countdown and its visual representation.
public struct AwakeTimeline: Equatable, Sendable {
    public let startedAt: Date
    public let endsAt: Date?

    public init(startedAt: Date, endsAt: Date?) {
        self.startedAt = startedAt
        self.endsAt = endsAt
    }

    public func remainingFraction(at now: Date = .now) -> Double {
        guard let endsAt else { return 1 }
        let duration = endsAt.timeIntervalSince(startedAt)
        guard duration > 0 else { return 0 }
        return min(1, max(0, endsAt.timeIntervalSince(now) / duration))
    }
}
