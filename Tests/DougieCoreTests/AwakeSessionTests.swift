import Foundation
import Testing
@testable import DougieCore

@MainActor
private final class FakePower: SleepPreventing {
    struct Request: Equatable {
        let display: Bool
        let timeout: TimeInterval
    }
    var requests: [Request] = []
    var stopCount = 0
    var shouldFail = false

    func start(keepDisplayAwake: Bool, timeout: TimeInterval) throws {
        if shouldFail { throw CocoaError(.featureUnsupported) }
        requests.append(Request(display: keepDisplayAwake, timeout: timeout))
    }

    func stop() { stopCount += 1 }
}

@MainActor
private struct Fixture {
    let suite = "DougieTests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let power = FakePower()
    let session: AwakeSession
    // A future instant keeps one-shot timers from firing during deterministic tests.
    let now = Date.now.addingTimeInterval(86_400)

    init() {
        defaults = UserDefaults(suiteName: suite)!
        session = AwakeSession(defaults: defaults, power: power)
    }

    func cleanUp() {
        session.stop()
        defaults.removePersistentDomain(forName: suite)
    }
}

@Suite @MainActor
struct AwakeSessionTests {
    @Test func coffeeTracksElapsedTimeWithoutNeedingUpdates() throws {
        let f = Fixture()
        defer { f.cleanUp() }
        f.session.setDuration(.oneHour, now: f.now)
        f.session.start(now: f.now)
        let clock = try #require(f.session.timeline)
        #expect(clock.remainingFraction(at: f.now.addingTimeInterval(-1)) == 1)
        #expect(clock.remainingFraction(at: f.now) == 1)
        #expect(clock.remainingFraction(at: f.now.addingTimeInterval(1800)) == 0.5)
        #expect(clock.remainingFraction(at: f.now.addingTimeInterval(2700)) == 0.25)
        #expect(clock.remainingFraction(at: f.now.addingTimeInterval(3600)) == 0)
        #expect(clock.remainingFraction(at: f.now.addingTimeInterval(7200)) == 0)
        #expect(f.power.requests.count == 1)
        f.session.expireIfNeeded(now: f.now.addingTimeInterval(7200))
        #expect(f.session.timeline == nil)
    }

    @Test func refillingRestartsTheSameDuration() throws {
        let f = Fixture()
        defer { f.cleanUp() }
        f.session.setDuration(.oneHour, now: f.now)
        f.session.start(now: f.now)
        let previous = try #require(f.session.timeline)
        let refillTime = f.now.addingTimeInterval(1800)
        f.session.start(now: refillTime)
        let refilled = try #require(f.session.timeline)
        #expect(refilled != previous)
        #expect(refilled.startedAt == refillTime)
        #expect(refilled.endsAt == refillTime.addingTimeInterval(3600))
        #expect(refilled.remainingFraction(at: refillTime) == 1)
        #expect(f.power.requests.last?.timeout == 3600)
        #expect(f.session.duration == .oneHour)
    }

    @Test func failedRefillPreservesCoffeeAndDeadline() throws {
        let f = Fixture()
        defer { f.cleanUp() }
        f.session.setDuration(.oneHour, now: f.now)
        f.session.start(now: f.now)
        let previous = try #require(f.session.timeline)
        f.power.shouldFail = true
        f.session.start(now: f.now.addingTimeInterval(1800))
        #expect(f.session.timeline == previous)
        #expect(f.session.timeline?.remainingFraction(at: f.now.addingTimeInterval(1800)) == 0.5)
        #expect(f.session.errorMessage != nil)
        #expect(f.power.requests.count == 1)
    }

    @Test func indefiniteCoffeeStaysFullAndCanRefill() throws {
        let f = Fixture()
        defer { f.cleanUp() }
        f.session.start(now: f.now)
        let previous = try #require(f.session.timeline)
        #expect(previous.remainingFraction(at: f.now.addingTimeInterval(86_400)) == 1)
        f.session.start(now: f.now.addingTimeInterval(60))
        #expect(f.session.timeline != previous)
        #expect(f.session.endsAt == nil)
        #expect(f.power.requests.last?.timeout == 0)
    }

    @Test func startsAndStopsWithoutATimer() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.session.start(now: f.now)
        #expect(f.session.isActive)
        #expect(f.session.endsAt == nil)
        #expect(f.power.requests == [.init(display: false, timeout: 0)])
        f.session.stop()
        #expect(!f.session.isActive)
        #expect(f.power.stopCount == 1)
    }

    @Test func changingDisplayPreservesRemainingDuration() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.session.setDuration(.fifteenMinutes, now: f.now)
        f.session.start(now: f.now)
        let originalTimeline = f.session.timeline
        f.session.setKeepDisplayAwake(true, now: f.now.addingTimeInterval(300))
        #expect(f.session.timeline == originalTimeline)
        #expect(f.session.endsAt == f.now.addingTimeInterval(900))
        #expect(f.power.requests.last == .init(display: true, timeout: 600))
        #expect(f.session.keepDisplayAwake)
    }

    @Test func changingDurationRestartsCountdown() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.session.setDuration(.fifteenMinutes, now: f.now)
        f.session.start(now: f.now)
        f.session.setDuration(.oneHour, now: f.now.addingTimeInterval(60))
        #expect(f.session.timeline?.startedAt == f.now.addingTimeInterval(60))
        #expect(f.session.timeline?.remainingFraction(at: f.now.addingTimeInterval(60)) == 1)
        #expect(f.session.endsAt == f.now.addingTimeInterval(3660))
        #expect(f.power.requests.last?.timeout == 3600)
        f.session.setDuration(.indefinitely, now: f.now.addingTimeInterval(120))
        #expect(f.session.endsAt == nil)
        #expect(f.power.requests.last?.timeout == 0)
    }

    @Test func expiresOnDeadlineAndAfterWake() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.session.setDuration(.fifteenMinutes, now: f.now)
        f.session.start(now: f.now)
        f.session.expireIfNeeded(now: f.now.addingTimeInterval(899))
        #expect(f.session.isActive)
        f.session.expireIfNeeded(now: f.now.addingTimeInterval(900))
        #expect(!f.session.isActive)
        #expect(f.session.endsAt == nil)
        #expect(f.power.stopCount == 1)
        f.session.start(now: f.now)
        f.session.expireIfNeeded(now: f.now.addingTimeInterval(7200))
        #expect(!f.session.isActive)
    }

    @Test func displayChangeDoesNotReviveExpiredSession() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.session.setDuration(.fifteenMinutes, now: f.now)
        f.session.start(now: f.now)
        f.session.setKeepDisplayAwake(true, now: f.now.addingTimeInterval(1000))
        #expect(!f.session.isActive)
        #expect(f.power.requests.count == 1)
        #expect(f.session.keepDisplayAwake)
    }

    @Test func failedStartDoesNotClaimToBeAwake() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.power.shouldFail = true
        f.session.start(now: f.now)
        #expect(!f.session.isActive)
        #expect(f.session.endsAt == nil)
        #expect(f.session.errorMessage != nil)
        f.power.shouldFail = false
        f.session.start(now: f.now)
        #expect(f.session.isActive)
        #expect(f.session.errorMessage == nil)
    }

    @Test func failedReconfigurationPreservesWorkingSessionAndPreferences() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.session.setDuration(.fifteenMinutes, now: f.now)
        f.session.start(now: f.now)
        f.power.shouldFail = true
        f.session.setKeepDisplayAwake(true, now: f.now)
        f.session.setDuration(.oneHour, now: f.now)
        #expect(f.session.isActive)
        #expect(!f.session.keepDisplayAwake)
        #expect(f.session.duration == .fifteenMinutes)
        #expect(f.session.endsAt == f.now.addingTimeInterval(900))
        #expect(!f.defaults.bool(forKey: "keepDisplayAwake"))
        #expect(f.defaults.integer(forKey: "durationMinutes") == 15)
        #expect(f.power.stopCount == 0)
    }

    @Test func preferencesPersistButActiveSessionsDoNot() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.session.setDuration(.twoHours, now: f.now)
        f.session.setKeepDisplayAwake(true, now: f.now)
        f.session.startOnLaunch = false
        f.session.start(now: f.now)
        let restored = AwakeSession(defaults: f.defaults, power: FakePower())
        #expect(restored.duration == .twoHours)
        #expect(restored.keepDisplayAwake)
        #expect(!restored.startOnLaunch)
        #expect(!restored.isActive)
        restored.launch()
        #expect(!restored.isActive)
    }

    @Test func startupOptInStartsSelectedMode() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.session.startOnLaunch = true
        f.session.setKeepDisplayAwake(true)
        f.session.launch()
        #expect(f.session.isActive)
        #expect(f.power.requests.last?.display == true)
    }
}
