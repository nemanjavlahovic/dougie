import AppKit
import DougieCore
import SwiftUI

struct AwakePanel: View {
    @Bindable var session: AwakeSession
    let login: LoginSettings
    @State private var showsStartup = false
    @State private var isVisible = false
    @Environment(\.colorScheme) private var colorScheme

    private var ink: Color {
        colorScheme == .dark
            ? Color(red: 0.95, green: 0.94, blue: 0.90)
            : Color(red: 0.16, green: 0.17, blue: 0.14)
    }

    private var detail: Color {
        colorScheme == .dark
            ? Color(red: 0.69, green: 0.71, blue: 0.66)
            : Color(red: 0.38, green: 0.40, blue: 0.35)
    }

    private var paper: Color {
        colorScheme == .dark
            ? Color(red: 0.14, green: 0.15, blue: 0.13)
            : Color(red: 0.95, green: 0.94, blue: 0.90)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            CoffeeCup(timeline: session.timeline, isVisible: isVisible)
                .frame(height: 190)
                .padding(.top, 4)
                .padding(.bottom, 16)
            awakeControl
            Divider()
                .padding(.vertical, 18)
            configuration
            HStack(alignment: .top, spacing: 16) {
                startup
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Quit") {
                    session.stop()
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
                .buttonStyle(.borderless)
                .font(.system(size: 11))
                .foregroundStyle(detail)
            }
            .padding(.top, 18)
            if let message = session.errorMessage {
                errorNotice(message)
                    .padding(.top, 14)
            }
            footer
                .padding(.top, 14)
        }
        .padding(20)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(ink)
        .tint(Color(red: 0.30, green: 0.45, blue: 0.27))
        .background(paper)
        .onAppear {
            session.expireIfNeeded()
            login.refresh()
            isVisible = true
        }
        .onDisappear { isVisible = false }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            login.refresh()
            session.expireIfNeeded()
        }
    }

    private var header: some View {
        Text("Dougie")
            .font(.custom("Georgia-Bold", size: 27))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 52, alignment: .topLeading)
    }

    private var awakeControl: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: Binding(
                get: { session.isActive },
                set: { $0 ? session.start() : session.stop() }
            )) {
                Text("Keep awake")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.switch)
            .accessibilityLabel("Keep awake")
            .accessibilityIdentifier("keep-awake")

            Group {
                if let end = session.endsAt, let timeline = session.timeline {
                    HStack(spacing: 4) {
                        // Clamp at zero if the run loop is briefly busy at expiry.
                        Text(timerInterval: timeline.startedAt...end, countsDown: true)
                            .monospacedDigit()
                            .fixedSize()
                        Text("remaining · until \(end.formatted(date: .omitted, time: .shortened))")
                    }
                } else {
                    Text(session.isActive ? "Until you turn it off" : "Your Mac can sleep normally.")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(detail)
            .frame(height: 17, alignment: .leading)

            HStack(spacing: 8) {
                Text("Duration")
                    .font(.system(size: 12))
                Picker("Duration", selection: Binding(
                    get: { session.duration },
                    set: { session.setDuration($0) }
                )) {
                    ForEach(AwakeDuration.allCases) { duration in
                        Text(duration == .indefinitely ? "Unlimited" : duration.title).tag(duration)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Duration")
                .accessibilityIdentifier("duration")
                .help("Changing the duration while awake refills the cup and starts a new countdown.")
                Button("Refill", systemImage: "arrow.clockwise") { session.start() }
                    .controlSize(.small)
                    .disabled(!session.isActive)
                    .accessibilityIdentifier("refill")
                    .accessibilityHint("Refills the cup and restarts the selected duration.")
                    .help("Refill the cup and restart the selected duration.")
            }
            .padding(.top, 8)
        }
    }

    private var configuration: some View {
        Toggle(isOn: Binding(
            get: { session.keepDisplayAwake },
            set: { session.setKeepDisplayAwake($0) }
        )) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Keep display awake")
                    .font(.system(size: 12))
                Text("Turn off to let the screen sleep.")
                    .font(.system(size: 11))
                    .foregroundStyle(detail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .accessibilityLabel("Keep display awake")
        .accessibilityIdentifier("keep-display-awake")
    }

    private var startup: some View {
        DisclosureGroup("Startup", isExpanded: $showsStartup) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Keep awake when app opens", isOn: $session.startOnLaunch)
                    .accessibilityIdentifier("start-awake")
                Toggle("Launch at login", isOn: Binding(
                    get: { login.isEnabled },
                    set: { login.setEnabled($0) }
                ))
                .disabled(login.isUpdating)
                .accessibilityIdentifier("launch-at-login")
                if login.needsApproval {
                    Text("Allow Dougie in Login Items to finish setup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Login Items") { login.openSystemSettings() }
                }
                if let message = login.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .padding(.top, 10)
            .padding(.leading, 2)
        }
        .font(.system(size: 12))
    }

    private func errorNotice(_ message: String) -> some View {
        HStack(alignment: .top) {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
            Button("Dismiss", systemImage: "xmark") { session.dismissError() }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
    }

    private var footer: some View {
        Text("Lid close and manual Sleep\nstill work normally.")
            .font(.system(size: 11))
            .foregroundStyle(detail)
            .fixedSize(horizontal: false, vertical: true)
    }
}
