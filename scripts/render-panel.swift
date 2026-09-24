import AppKit
import DougieCore
import SwiftUI

@MainActor
private final class PreviewPower: SleepPreventing {
    func start(keepDisplayAwake: Bool, timeout: TimeInterval) throws {}
    func stop() {}
}

@main
struct RenderPanel {
    @MainActor
    static func main() throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "Dougie.Render.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let session = AwakeSession(defaults: defaults, power: PreviewPower())
        for (name, active, dark, elapsed) in [
            ("mac-off-light", false, false, 0.0),
            ("mac-on-light", true, false, 0.0),
            ("mac-on-dark", true, true, 0.0),
            ("mac-half-light", true, false, 1800.0),
            ("mac-half-dark", true, true, 1800.0),
            ("mac-low-dark", true, true, 3240.0)
        ] {
            if active {
                session.setDuration(.oneHour)
                session.start(now: .now.addingTimeInterval(-elapsed))
            } else { session.stop() }
            let panel = AwakePanel(session: session, login: LoginSettings())
                .background(Color(nsColor: .windowBackgroundColor))
                .environment(\.colorScheme, dark ? .dark : .light)
            let host = NSHostingView(rootView: panel)
            host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            let size = host.fittingSize
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host
            host.frame = NSRect(origin: .zero, size: size)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date.now.addingTimeInterval(0.1))
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
                fatalError("Unable to render panel")
            }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                fatalError("Unable to encode panel")
            }
            try data.write(to: directory.appendingPathComponent("\(name).png"))
            print("Rendered \(name): \(size)")
            window.orderOut(nil)
        }
        session.stop()
    }
}
