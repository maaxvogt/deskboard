import SwiftUI

/// Now playing on Spotify: artwork on the left, track info, then one row with
/// the transport controls and the progress bar.
struct SpotifyWidget: View {
    @State private var service = SpotifyService()

    var body: some View {
        WidgetCard("Spotify", tint: Theme.tintSpotify) {
            if let placeholder = service.placeholder {
                WidgetPlaceholder(text: placeholder)
            } else if let playback = service.playback {
                player(playback)
            } else {
                WidgetPlaceholder(text: "Nothing playing")
            }
        }
        .task {
            await service.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await service.refresh()
            }
        }
    }

    private func player(_ playback: SpotifyPlayback) -> some View {
        HStack(alignment: .top, spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 3) {
                Text(playback.title)
                    .font(Theme.bodyMedium)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(playback.album.isEmpty ? playback.artist : "\(playback.artist) · \(playback.album)")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                if let error = service.controlError {
                    Text(error)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.warn)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    controlsRow(playback, now: context.date)
                }
            }
        }
    }

    @ViewBuilder private var artwork: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        Group {
            if let image = service.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                shape.fill(Theme.fill)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.faint)
                    }
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(shape)
    }

    private func controlsRow(_ playback: SpotifyPlayback, now: Date) -> some View {
        let position = playback.position(at: now)
        return HStack(spacing: 8) {
            HStack(spacing: 6) {
                control("backward.fill", size: 11) { await service.previous() }
                control(playback.isPlaying ? "pause.fill" : "play.fill", size: 15) { await service.playPause() }
                control("forward.fill", size: 11) { await service.next() }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.fill)
                    Capsule()
                        .fill(Theme.tintSpotify.accent)
                        .frame(width: max(4, geo.size.width * fraction(position, of: playback.duration)))
                }
            }
            .frame(height: 4)
            Text(timeLabel(position))
                .font(Theme.caption.monospacedDigit())
                .foregroundStyle(Theme.faint)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private func control(_ symbol: String, size: CGFloat, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func fraction(_ position: TimeInterval, of duration: TimeInterval) -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(min(1, max(0, position / duration)))
    }

    private func timeLabel(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
