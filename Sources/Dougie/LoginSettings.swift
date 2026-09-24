import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class LoginSettings {
    private(set) var isEnabled = false
    private(set) var needsApproval = false
    private(set) var isUpdating = false
    private(set) var errorMessage: String?

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled || status == .requiresApproval
        needsApproval = status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        guard !isUpdating else { return }
        isUpdating = true
        errorMessage = nil
        Task {
            defer {
                refresh()
                isUpdating = false
            }
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try await SMAppService.mainApp.unregister()
                }
            } catch {
                errorMessage = "Couldn’t change launch at login. Try again or check Login Items in System Settings."
            }
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
