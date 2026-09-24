import Foundation
import Observation

public enum AwakeDuration: Int, CaseIterable, Identifiable, Sendable {
    case indefinitely = 0
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120
    case fourHours = 240
    case eightHours = 480

    public var id: Int { rawValue }
    public var seconds: TimeInterval? { self == .indefinitely ? nil : Double(rawValue * 60) }
    public var title: String {
        switch self {
        case .indefinitely: "Until I turn it off"
        case .fifteenMinutes: "15 minutes"
        case .thirtyMinutes: "30 minutes"
        case .oneHour: "1 hour"
        case .twoHours: "2 hours"
        case .fourHours: "4 hours"
        case .eightHours: "8 hours"
        }
    }
}

@MainActor
@Observable
public final class AwakeSession {
    public private(set) var timeline: AwakeTimeline?
    public var isActive: Bool { timeline != nil }
    public var endsAt: Date? { timeline?.endsAt }
    public private(set) var errorMessage: String?
    public private(set) var duration: AwakeDuration
    public private(set) var keepDisplayAwake: Bool
    public var startOnLaunch: Bool {
        didSet { defaults.set(startOnLaunch, forKey: "startOnLaunch") }
    }

    @ObservationIgnored private let power: any SleepPreventing
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var stopTimer: Timer?

    public init(defaults: UserDefaults = .standard, power: any SleepPreventing = PowerAssertion()) {
        self.defaults = defaults
        self.power = power
        duration = AwakeDuration(rawValue: defaults.integer(forKey: "durationMinutes")) ?? .indefinitely
        keepDisplayAwake = defaults.bool(forKey: "keepDisplayAwake")
        startOnLaunch = defaults.object(forKey: "startOnLaunch") as? Bool ?? true
    }

    public func launch() {
        if startOnLaunch { start() }
    }

    public func start(now: Date = .now) {
        let deadline = duration.seconds.map { now.addingTimeInterval($0) }
        guard enablePower(display: keepDisplayAwake, deadline: deadline, now: now) else { return }
        timeline = AwakeTimeline(startedAt: now, endsAt: deadline)
        scheduleStop()
    }

    public func stop() {
        stopTimer?.invalidate()
        stopTimer = nil
        power.stop()
        timeline = nil
        errorMessage = nil
    }

    public func setKeepDisplayAwake(_ enabled: Bool, now: Date = .now) {
        expireIfNeeded(now: now)
        if isActive && !enablePower(display: enabled, deadline: endsAt, now: now) { return }
        keepDisplayAwake = enabled
        defaults.set(enabled, forKey: "keepDisplayAwake")
    }

    /// Changing the duration starts a fresh countdown if a session is already active.
    public func setDuration(_ newDuration: AwakeDuration, now: Date = .now) {
        expireIfNeeded(now: now)
        if isActive {
            let deadline = newDuration.seconds.map { now.addingTimeInterval($0) }
            guard enablePower(display: keepDisplayAwake, deadline: deadline, now: now) else { return }
            timeline = AwakeTimeline(startedAt: now, endsAt: deadline)
            scheduleStop()
        }
        duration = newDuration
        defaults.set(newDuration.rawValue, forKey: "durationMinutes")
    }

    public func expireIfNeeded(now: Date = .now) {
        if isActive, let endsAt, now >= endsAt { stop() }
    }

    public func dismissError() { errorMessage = nil }

    private func enablePower(display: Bool, deadline: Date?, now: Date) -> Bool {
        do {
            try power.start(keepDisplayAwake: display, timeout: deadline.map { max(0.001, $0.timeIntervalSince(now)) } ?? 0)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func scheduleStop() {
        stopTimer?.invalidate()
        stopTimer = nil
        guard let endsAt else { return }
        let timer = Timer(fire: endsAt, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.expireIfNeeded() }
        }
        stopTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        // The power assertion has the same OS-enforced timeout even if this app is suspended.
    }
}
