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
        if CommandLine.arguments.dropFirst(2).contains("--demo") {
            try renderDemo(to: directory, session: session)
            session.stop()
            return
        }
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
            try render(name: name, dark: dark, session: session, to: directory)
        }
        session.stop()
    }

    @MainActor
    private static func renderDemo(to directory: URL, session: AwakeSession) throws {
        session.setDuration(.oneHour)
        // A five-second explanation: off, start, accelerated countdown, refill.
        for frame in 0..<60 {
            switch frame {
            case 0..<8:
                session.stop()
            case 8..<20:
                session.start()
            case 20..<48:
                let progress = Double(frame - 20) / 27
                session.start(now: .now.addingTimeInterval(-progress * 3_000))
            default:
                session.start()
            }
            try render(name: String(format: "frame-%03d", frame), dark: false,
                       session: session, to: directory, announce: false)
        }
    }

    @MainActor
    private static func render(name: String, dark: Bool, session: AwakeSession,
                               to directory: URL, announce: Bool = true) throws {
        let panel = AwakePanel(session: session, login: LoginSettings())
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: panel)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let size = host.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
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
        if announce { print("Rendered \(name): \(size)") }
        window.orderOut(nil)
    }
}
