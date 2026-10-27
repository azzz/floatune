import AppKit
import Observation

/// Player state read from Spotify in one Apple Event round trip.
struct PlayerSnapshot: Sendable, Equatable {
    enum State: String, Sendable {
        case playing, paused, stopped
    }

    var state: State
    var volume: Int
    var title = ""
    var artist = ""
    var album = ""
    var artworkURL: URL?
    var trackID = ""
    var duration: TimeInterval = 0
    /// Position at the moment the snapshot was read.
    var position: TimeInterval = 0
}

/// Whether Spotify can be controlled right now.
enum SpotifyStatus: Equatable {
    case notRunning
    case noPermission
    case ready
}

/// Spotify state for the UI and the commands that change it.
@MainActor
@Observable
final class SpotifyController {
    nonisolated static let bundleID = "com.spotify.client"

    private(set) var status: SpotifyStatus = .notRunning
    private(set) var snapshot: PlayerSnapshot?
    private(set) var artwork: NSImage?
    /// Volume shown by the slider. Changes locally before Spotify confirms them.
    private(set) var volume: Double = 50
    /// When `snapshot.position` was true. Used to extrapolate the position while playing.
    private(set) var positionDate = Date()

    /// Progress slider value while the user drags it; nil otherwise.
    var scrubPosition: TimeInterval?

    /// Set by the panel. While true and playing, the position is re-read every few seconds,
    /// because Spotify sends no notification on seek.
    var isVisible = false {
        didSet { if isVisible != oldValue { updateSync() } }
    }

    @ObservationIgnored private let scripts = AppleScriptRunner()
    @ObservationIgnored private var artworkURL: URL?
    @ObservationIgnored private var pendingVolume: Int?
    @ObservationIgnored private var isSendingVolume = false
    @ObservationIgnored private var isRetryScheduled = false
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    /// Subscribes to Spotify and workspace notifications and reads the initial state.
    func start() {
        let distributed = DistributedNotificationCenter.default()
        let token = distributed.addObserver(
            forName: Notification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        observers.append((distributed, token))

        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            let token = workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard app?.bundleIdentifier == Self.bundleID else { return }
                Task { @MainActor in
                    // Spotify ignores Apple Events for a moment after launch.
                    if name == NSWorkspace.didLaunchApplicationNotification {
                        try? await Task.sleep(for: .seconds(1.5))
                    }
                    await self?.refresh()
                }
            }
            observers.append((workspace, token))
        }

        Task { await refresh() }
    }

    /// Reads player state from Spotify. Does nothing to Spotify if it is not running.
    func refresh() async {
        guard isRunning else {
            setNotRunning()
            return
        }
        switch await scripts.run(Scripts.state) {
        case .success(let text):
            guard let snapshot = Self.parse(text) else { return }
            status = .ready
            self.snapshot = snapshot
            positionDate = Date()
            updateSync()
            if pendingVolume == nil, !isSendingVolume {
                volume = Double(snapshot.volume)
            }
            loadArtwork(snapshot.artworkURL)
        case .failure(.notPermitted):
            status = .noPermission
        case .failure(.notRunning):
            setNotRunning()
        case .failure(.other):
            // Usually a timeout: Spotify is starting or the Automation prompt is still open.
            if status == .notRunning { status = .ready }
            scheduleRetry()
        }
    }

    private func updateSync() {
        let shouldSync = isVisible && status == .ready && snapshot?.state == .playing
        if shouldSync, syncTask == nil {
            syncTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    if Task.isCancelled { break }
                    await refresh()
                }
            }
        } else if !shouldSync {
            syncTask?.cancel()
            syncTask = nil
        }
    }

    private func scheduleRetry() {
        guard !isRetryScheduled else { return }
        isRetryScheduled = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            isRetryScheduled = false
            await refresh()
        }
    }

    func playPause() {
        if var snapshot, snapshot.state != .stopped {
            let now = Date()
            snapshot.position = position(at: now)
            snapshot.state = snapshot.state == .playing ? .paused : .playing
            self.snapshot = snapshot
            positionDate = now
            updateSync()
        }
        send("playpause")
    }

    /// Track position at `date`, extrapolated from the last snapshot while playing.
    func position(at date: Date) -> TimeInterval {
        guard let snapshot else { return 0 }
        guard snapshot.state == .playing else { return snapshot.position }
        return min(snapshot.position + date.timeIntervalSince(positionDate), snapshot.duration)
    }

    /// Moves playback to `seconds` from the track start.
    func seek(to seconds: TimeInterval) {
        guard var snapshot, isRunning else { return }
        snapshot.position = seconds
        self.snapshot = snapshot
        positionDate = Date()
        // AppleScript source always uses a period as the decimal separator.
        send("set player position to \(String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), seconds))", cache: false)
    }

    func next() { send("next track") }

    func previous() { send("previous track") }

    /// Sets Spotify volume (0–100). Sends at most one Apple Event per 50 ms while the slider moves.
    func setVolume(_ value: Double) {
        volume = value
        pendingVolume = Int(value.rounded())
        guard !isSendingVolume else { return }
        isSendingVolume = true
        Task {
            while let target = pendingVolume {
                pendingVolume = nil
                if isRunning {
                    _ = await scripts.run(Scripts.tell("set sound volume to \(target)"), cache: false)
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
            isSendingVolume = false
        }
    }

    func launchSpotify() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    func openAutomationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }

    private var isRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID)
            .contains { !$0.isTerminated }
    }

    // Any Apple Event launches Spotify if it is closed, so every command checks first.
    private func send(_ command: String, cache: Bool = true) {
        guard isRunning else { return }
        Task {
            if case .failure(.notPermitted) = await scripts.run(Scripts.tell(command), cache: cache) {
                status = .noPermission
            }
        }
    }

    private func setNotRunning() {
        status = .notRunning
        syncTask?.cancel()
        syncTask = nil
        snapshot = nil
        artwork = nil
        artworkURL = nil
    }

    private func loadArtwork(_ url: URL?) {
        guard url != artworkURL else { return }
        artworkURL = url
        artwork = nil
        guard let url else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  url == artworkURL else { return }
            artwork = NSImage(data: data)
        }
    }

    private static func parse(_ text: String) -> PlayerSnapshot? {
        let fields = text.components(separatedBy: "\n")
        guard fields.count >= 2,
              let state = PlayerSnapshot.State(rawValue: fields[0]),
              let volume = Int(fields[1]) else { return nil }
        var snapshot = PlayerSnapshot(state: state, volume: volume)
        guard fields.count >= 7 else { return snapshot }
        snapshot.title = fields[2]
        snapshot.artist = fields[3]
        snapshot.album = fields[4]
        snapshot.artworkURL = URL(string: fields[5])
        snapshot.trackID = fields[6]
        if fields.count >= 9 {
            snapshot.duration = (Double(fields[7]) ?? 0) / 1000
            snapshot.position = (Double(fields[8]) ?? 0) / 1000
        }
        return snapshot
    }
}

/// AppleScript sources sent to Spotify.
private enum Scripts {
    /// Returns lines: state, volume, then title, artist, album, artwork URL, track ID,
    /// duration and position unless stopped. Duration and position are integer milliseconds,
    /// because a real coerced to text uses the locale decimal separator.
    static let state = """
    with timeout of 2 seconds
        tell application id "com.spotify.client"
            set s to player state as string
            set out to s & linefeed & (sound volume as string)
            if s is "stopped" then return out
            set t to current track
            set n to ""
            set a to ""
            set al to ""
            set art to ""
            set i to ""
            set d to 0
            set p to 0
            try
                set n to name of t
            end try
            try
                set a to artist of t
            end try
            try
                set al to album of t
            end try
            try
                set art to artwork url of t
            end try
            try
                set i to id of t
            end try
            try
                set d to duration of t
            end try
            try
                set p to round ((player position) * 1000)
            end try
            return out & linefeed & n & linefeed & a & linefeed & al & linefeed & art & linefeed & i & linefeed & d & linefeed & p
        end tell
    end timeout
    """

    static func tell(_ command: String) -> String {
        """
        with timeout of 2 seconds
            tell application id "com.spotify.client" to \(command)
        end timeout
        """
    }
}

/// Compiles and runs AppleScripts on one serial queue, keeping compiled scripts for reuse.
final class AppleScriptRunner: @unchecked Sendable {
    enum Failure: Error {
        case notPermitted
        case notRunning
        case other(Int)
    }

    private let queue = DispatchQueue(label: "SpotifyMini.AppleScript", qos: .userInitiated)
    // Touched only on `queue`.
    private var compiled: [String: NSAppleScript] = [:]

    /// Runs `source` and returns its string result. `cache: false` skips keeping the compiled script.
    func run(_ source: String, cache: Bool = true) async -> Result<String, Failure> {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.execute(source, cache: cache))
            }
        }
    }

    private func execute(_ source: String, cache: Bool) -> Result<String, Failure> {
        let script: NSAppleScript
        if let cached = compiled[source] {
            script = cached
        } else {
            guard let fresh = NSAppleScript(source: source) else { return .failure(.other(0)) }
            script = fresh
            if cache { compiled[source] = fresh }
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            switch code {
            case -1743: return .failure(.notPermitted)  // errAEEventNotPermitted
            case -600, -609: return .failure(.notRunning)  // procNotFound, connectionInvalid
            default: return .failure(.other(code))
            }
        }
        return .success(result.stringValue ?? "")
    }
}
