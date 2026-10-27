import SwiftUI

/// Panel content: current track, transport buttons and volume.
struct PlayerView: View {
    let spotify: SpotifyController
    let openSettings: () -> Void

    var body: some View {
        Group {
            switch spotify.status {
            case .notRunning:
                message(
                    title: "Spotify не запущен",
                    detail: nil,
                    action: ("Открыть Spotify", spotify.launchSpotify)
                )
            case .noPermission:
                message(
                    title: "Нет доступа к Spotify",
                    detail: "Разрешите управление в Конфиденциальность → Автоматизация",
                    action: ("Открыть настройки", spotify.openAutomationSettings)
                )
            case .ready:
                player
            }
        }
        .padding(12)
        .frame(width: MiniPanel.size.width, height: MiniPanel.size.height)
        .contentShape(Rectangle())
        .contextMenu { menu }
    }

    private var player: some View {
        let snapshot = spotify.snapshot
        let stopped = snapshot == nil || snapshot?.state == .stopped

        return VStack(spacing: 6) {
            HStack(spacing: 12) {
                artwork
                details(snapshot: snapshot, stopped: stopped)
            }
            ProgressRow(spotify: spotify, enabled: !stopped)
        }
    }

    private func details(snapshot: PlayerSnapshot?, stopped: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(stopped ? "Ничего не играет" : snapshot?.title ?? "")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Text(stopped ? " " : snapshot?.artist ?? "")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 22) {
                transportButton("backward.fill", action: spotify.previous)
                transportButton(
                    snapshot?.state == .playing ? "pause.fill" : "play.fill",
                    action: spotify.playPause
                )
                transportButton("forward.fill", action: spotify.next)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 6) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(get: { spotify.volume }, set: { spotify.setVolume($0) }),
                    in: 0...100
                )
                .controlSize(.mini)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(.quaternary)
            if let image = spotify.artwork {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note").font(.system(size: 26)).foregroundStyle(.secondary)
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func transportButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func message(title: String, detail: String?, action: (String, () -> Void)) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 13, weight: .semibold))
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(action.0, action: action.1).controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var menu: some View {
        Button("Настройки…", action: openSettings)
        Divider()
        Button("Выйти") { NSApp.terminate(nil) }
    }
}

/// Elapsed time, seek slider and remaining time. Redraws twice a second only while playing and visible.
private struct ProgressRow: View {
    let spotify: SpotifyController
    let enabled: Bool

    var body: some View {
        let playing = spotify.snapshot?.state == .playing && spotify.isVisible
        TimelineView(.animation(minimumInterval: 0.5, paused: !playing)) { context in
            row(position: spotify.scrubPosition ?? spotify.position(at: context.date))
        }
    }

    private func row(position: TimeInterval) -> some View {
        let duration = max(spotify.snapshot?.duration ?? 0, 1)
        return HStack(spacing: 6) {
            Text(Self.format(position))
                .frame(width: 34, alignment: .trailing)
            Slider(
                value: Binding(
                    get: { min(position, duration) },
                    set: { spotify.scrubPosition = $0 }
                ),
                in: 0...duration,
                onEditingChanged: { editing in
                    if !editing, let target = spotify.scrubPosition {
                        spotify.seek(to: target)
                        spotify.scrubPosition = nil
                    }
                }
            )
            .controlSize(.mini)
            .disabled(!enabled)
            Text("-" + Self.format(max(duration - position, 0)))
                .frame(width: 38, alignment: .leading)
        }
        .font(.system(size: 10).monospacedDigit())
        .foregroundStyle(.secondary)
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
