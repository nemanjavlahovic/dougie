import Foundation
import IOKit.pwr_mgt
import Testing
@testable import DougieCore

@Suite(.serialized) @MainActor
struct PowerAssertionTests {
    private func properties(_ id: IOPMAssertionID) -> NSDictionary? {
        IOPMAssertionCopyProperties(id)?.takeRetainedValue() as NSDictionary?
    }

    @Test func realSystemAndDisplayAssertionsAreCreatedReplacedAndReleased() throws {
        let power = PowerAssertion()
        defer { power.stop() }
        try power.start(keepDisplayAwake: false, timeout: 10)
        let first = try #require(power.assertionID)
        #expect(properties(first)?[kIOPMAssertionTypeKey] as? String == kIOPMAssertPreventUserIdleSystemSleep)
        #expect(properties(first)?[kIOPMAssertionLevelKey] as? Int == Int(kIOPMAssertionLevelOn))
        try power.start(keepDisplayAwake: true, timeout: 10)
        let second = try #require(power.assertionID)
        #expect(first != second)
        #expect(properties(first) == nil)
        #expect(properties(second)?[kIOPMAssertionTypeKey] as? String == kIOPMAssertPreventUserIdleDisplaySleep)
        power.stop()
        #expect(power.assertionID == nil)
        #expect(properties(second) == nil)
    }

    @Test func macOSExpiresAssertionWithoutAnAppTimer() async throws {
        let power = PowerAssertion()
        defer { power.stop() }
        try power.start(keepDisplayAwake: false, timeout: 1)
        let id = try #require(power.assertionID)
        #expect(properties(id)?[kIOPMAssertionLevelKey] as? Int == Int(kIOPMAssertionLevelOn))
        try await Task.sleep(for: .seconds(2))
        #expect(properties(id) == nil)
    }

    @Test func ownerDeinitReleasesAssertion() throws {
        var power: PowerAssertion? = PowerAssertion()
        try power?.start(keepDisplayAwake: false, timeout: 10)
        let id = try #require(power?.assertionID)
        power = nil
        #expect(properties(id) == nil)
    }
}
