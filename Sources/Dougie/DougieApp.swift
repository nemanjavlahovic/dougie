import AppKit
import DougieCore
import SwiftUI

@main
struct DougieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            AwakePanel(session: delegate.session, login: delegate.login)
        } label: {
            Image(systemName: delegate.session.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                .accessibilityLabel(delegate.session.isActive ? "Dougie, keeping awake" : "Dougie, off")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let session = AwakeSession()
    let login = LoginSettings()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil
        )
        session.launch()
    }

    @objc private func didWake() {
        session.expireIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        session.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
