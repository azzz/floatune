import AppKit
import Carbon.HIToolbox

@main
@MainActor
enum SpotifyMiniApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

/// Owns the panel, the hotkey and the Spotify controller.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let spotify = SpotifyController()
    private var panel: MiniPanel?
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()

        let hosting = FirstMouseHostingView(rootView: PlayerView(spotify: spotify))
        let panel = MiniPanel(content: hosting)
        panel.onPresent = { [spotify] in
            spotify.isVisible = true
            Task { await spotify.refresh() }
        }
        panel.onHide = { [spotify] in
            spotify.isVisible = false
        }
        self.panel = panel

        hotKey = HotKey(
            keyCode: UInt32(kVK_ANSI_S),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        ) { [weak panel] in
            panel?.toggle()
        }

        spotify.start()
        panel.present()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel?.present()
        return false
    }
}

/// User-tunable values stored in UserDefaults.
enum Settings {
    static let dimDelayKey = "dimDelay"
    static let dimAlphaKey = "dimAlpha"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            dimDelayKey: 4.0,
            dimAlphaKey: 0.35,
        ])
    }

    /// Seconds without interaction before the panel dims.
    static var dimDelay: TimeInterval { UserDefaults.standard.double(forKey: dimDelayKey) }

    /// Panel opacity in the dimmed state.
    static var dimAlpha: CGFloat { CGFloat(UserDefaults.standard.double(forKey: dimAlphaKey)) }
}
