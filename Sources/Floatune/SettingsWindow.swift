import AppKit
import Observation
import SwiftUI

/// Captures the next key combination pressed in the app's key window.
@MainActor
@Observable
final class HotKeyRecorder {
    private(set) var isRecording = false

    /// Called when recording starts, so the owner can pause the global hotkey and let it be recorded.
    @ObservationIgnored var onStart: (() -> Void)?
    /// Called when recording ends, recorded or cancelled.
    @ObservationIgnored var onStop: (() -> Void)?

    @ObservationIgnored private var monitor: Any?

    /// Records one combo into `settings.hotKey`. Escape without modifiers cancels.
    func start(into settings: AppSettings) {
        guard !isRecording else { return }
        isRecording = true
        onStart?()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak settings] event in
            let keyCode = event.keyCode
            let flags = event.modifierFlags
            let combo = KeyCombo(event: event)
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let self else { return false }
                let bareModifiers = flags.intersection([.command, .option, .control, .shift])
                if keyCode == 53, bareModifiers.isEmpty { // Escape
                    self.stop()
                } else if let combo {
                    settings?.hotKey = combo
                    self.stop()
                }
                return true
            }
            // Swallow every key while recording, including combos rejected for lack of modifiers.
            return handled ? nil : event
        }
    }

    func stop() {
        guard isRecording else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        onStop?()
    }
}

/// Owns the settings window; creates it on first use.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let settings: AppSettings
    private let recorder: HotKeyRecorder
    private var window: NSWindow?

    init(settings: AppSettings, recorder: HotKeyRecorder) {
        self.settings = settings
        self.recorder = recorder
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        // An accessory app has to activate itself, or the window opens behind the frontmost app.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        recorder.stop()
    }

    /// Starts a new copy of the app once this one has quit, then quits.
    private static func relaunch() {
        // The new copy must start after this one exits, or its hotkey registration would collide.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = [
            "-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.1; done; /usr/bin/open \"$2\"",
            "relaunch", String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundlePath,
        ]
        try? task.run()
        NSApp.terminate(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(
            rootView: SettingsView(settings: settings, recorder: recorder, relaunch: Self.relaunch)
        ))
        window.title = String(localized: "Floatune Settings")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }
}

/// Hotkey, dimming, login-item and language settings.
struct SettingsView: View {
    let settings: AppSettings
    let recorder: HotKeyRecorder
    let relaunch: () -> Void

    var body: some View {
        Form {
            Section {
                LabeledContent("Show / hide") {
                    HStack(spacing: 8) {
                        Text(recorder.isRecording ? String(localized: "Press a shortcut…") : settings.hotKey.displayString)
                            .font(.system(size: 12, weight: .medium).monospaced())
                            .foregroundStyle(recorder.isRecording ? .secondary : .primary)
                            .frame(minWidth: 130)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 5).fill(.quaternary))
                        Button(recorder.isRecording ? String(localized: "Cancel") : String(localized: "Change")) {
                            if recorder.isRecording {
                                recorder.stop()
                            } else {
                                recorder.start(into: settings)
                            }
                        }
                        Button("Reset") { settings.hotKey = .default }
                            .disabled(settings.hotKey == .default || recorder.isRecording)
                    }
                }
                if let error = settings.hotKeyError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            } footer: {
                Text("The shortcut must include ⌘, ⌃ or ⌥. F1–F20 work without modifiers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("When idle") {
                LabeledContent("Dim after") {
                    HStack {
                        Slider(
                            value: Binding(get: { settings.dimDelay }, set: { settings.dimDelay = $0 }),
                            in: 1...15,
                            step: 1
                        )
                        Text(Duration.seconds(Int(settings.dimDelay)).formatted(.units(allowed: [.seconds], width: .abbreviated)))
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }
                }
                LabeledContent("Opacity") {
                    HStack {
                        Slider(
                            value: Binding(get: { settings.dimAlpha }, set: { settings.dimAlpha = $0 }),
                            in: 0.1...0.9,
                            step: 0.05
                        )
                        Text(settings.dimAlpha.formatted(.percent.precision(.fractionLength(0))))
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }

            Section {
                Toggle("Open at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                Picker("Language", selection: Binding(
                    get: { settings.language ?? "" },
                    set: { settings.setLanguage($0.isEmpty ? nil : $0) }
                )) {
                    Text("System").tag("")
                    ForEach(AppSettings.availableLanguages, id: \.self) { code in
                        Text(verbatim: AppSettings.displayName(of: code)).tag(code)
                    }
                }
                if settings.needsRelaunch {
                    HStack {
                        Text("Restart Floatune to apply the language.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Restart", action: relaunch)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}
