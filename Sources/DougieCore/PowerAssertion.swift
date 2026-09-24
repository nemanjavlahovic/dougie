import Foundation
import IOKit.pwr_mgt

@MainActor
public protocol SleepPreventing: AnyObject {
    func start(keepDisplayAwake: Bool, timeout: TimeInterval) throws
    func stop()
}

/// Owns one macOS power assertion. Display prevention also prevents idle system sleep.
@MainActor
public final class PowerAssertion: SleepPreventing {
    public private(set) var assertionID: IOPMAssertionID?

    public init() {}

    public func start(keepDisplayAwake: Bool, timeout: TimeInterval) throws {
        let type = keepDisplayAwake
            ? kIOPMAssertPreventUserIdleDisplaySleep
            : kIOPMAssertPreventUserIdleSystemSleep
        var newID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithDescription(
            type as CFString,
            "Dougie: keep awake" as CFString,
            "Keep this Mac awake at the user's request." as CFString,
            nil, nil,
            max(0, timeout),
            kIOPMAssertionTimeoutActionRelease as CFString,
            &newID
        )
        guard result == kIOReturnSuccess else {
            throw PowerError(code: result)
        }

        // Acquire the replacement first, preserving the current session if creation fails.
        stop()
        assertionID = newID
    }

    public func stop() {
        if let assertionID {
            IOPMAssertionRelease(assertionID)
            self.assertionID = nil
        }
    }

    deinit {
        if let assertionID { IOPMAssertionRelease(assertionID) }
    }
}

private struct PowerError: LocalizedError {
    let code: IOReturn

    var errorDescription: String? {
        "macOS couldn’t enable keep awake (\(code)). Try turning it on again."
    }
}
