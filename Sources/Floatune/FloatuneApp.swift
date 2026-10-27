import AppKit

@main
@MainActor
enum FloatuneApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

/// Owns the panel, the hotkey, settings and the Spotify controller.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let spotify = SpotifyController()
    private let settings = AppSettings()
    private let recorder = HotKeyRecorder()
    private var panel: MiniPanel?
    private var hotKey: HotKey?
    private var registeredCombo: KeyCombo?
    private lazy var settingsWindow = SettingsWindowController(settings: settings, recorder: recorder)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hosting = FirstMouseHostingView(rootView: PlayerView(
            spotify: spotify,
            openSettings: { [weak self] in self?.settingsWindow.show() }
        ))
        let panel = MiniPanel(content: hosting, settings: settings)
        panel.onPresent = { [spotify] in
            spotify.isVisible = true
            Task { await spotify.refresh() }
        }
        panel.onHide = { [spotify] in
            spotify.isVisible = false
        }
        self.panel = panel

        hotKey = HotKey { [weak panel] in
            panel?.toggle()
        }
        registerHotKey()

        settings.onChange = { [weak self] in
            guard let self else { return }
            self.panel?.settingsDidChange()
            if !self.recorder.isRecording, self.settings.hotKey != self.registeredCombo {
                self.registerHotKey()
            }
        }
        recorder.onStart = { [weak self] in
            self?.hotKey?.unregister()
            self?.registeredCombo = nil
        }
        recorder.onStop = { [weak self] in
            self?.registerHotKey()
        }

        spotify.start()
        panel.present()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel?.present()
        return false
    }

    private func registerHotKey() {
        let combo = settings.hotKey
        if hotKey?.register(combo) == true {
            registeredCombo = combo
            settings.hotKeyError = nil
        } else {
            registeredCombo = nil
            settings.hotKeyError = String(localized: "Couldn't register \(combo.displayString): the shortcut is taken.")
        }
    }
}
