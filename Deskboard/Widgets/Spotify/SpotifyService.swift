import AppKit
import Foundation
import Observation

/// What the widget needs to know about the current track. `position` is the
/// playhead at `fetchedAt`; use `position(at:)` to interpolate between polls.
struct SpotifyPlayback: Equatable {
    let trackID: String
    let title: String
    let artist: String
    let album: String
    let artworkURL: URL?
    let duration: TimeInterval
    let position: TimeInterval
    let isPlaying: Bool
    let fetchedAt: Date

    func position(at date: Date) -> TimeInterval {
        guard isPlaying else { return position }
        return min(duration, position + date.timeIntervalSince(fetchedAt))
    }
}

/// Where the playback state comes from and where the controls go. The widget
/// only talks to this seam, so the actual source (local Spotify app, Web API)
/// can be swapped without touching the view.
protocol SpotifyBackend {
    /// nil = Spotify reachable but nothing loaded.
    func fetch() async throws -> SpotifyPlayback?
    func playPause() async throws
    func next() async throws
    func previous() async throws
}

/// Fixed sample track for `--demo`. Keeps "playing" by advancing the playhead
/// from the moment the widget first asked.
struct DemoSpotifyBackend: SpotifyBackend {
    private let started = Date()

    func fetch() async throws -> SpotifyPlayback? {
        Demo.spotify(started: started)
    }

    func playPause() async throws {}
    func next() async throws {}
    func previous() async throws {}
}

@Observable
final class SpotifyService {
    private(set) var playback: SpotifyPlayback?
    private(set) var artwork: NSImage?
    /// Shown instead of the player when the source is unavailable.
    private(set) var placeholder: String?
    /// Transient control failure (e.g. Premium required), shown under the row.
    private(set) var controlError: String?

    private let backend: SpotifyBackend
    private var artworkURL: URL?

    init() {
        backend = Demo.active ? DemoSpotifyBackend() : SpotifyWebAPI()
    }

    func refresh() async {
        if !Demo.active {
            if SpotifyAuth.shared.clientID.isEmpty {
                placeholder = "Add your Spotify Client ID in Settings"
                playback = nil
                return
            }
            if !SpotifyAuth.shared.isConnected {
                placeholder = "Connect Spotify in Settings"
                playback = nil
                return
            }
        }
        do {
            let state = try await backend.fetch()
            placeholder = nil
            // Keep the last state during a rate-limit hiccup instead of flashing.
            playback = state
            await loadArtwork(for: state)
        } catch {
            placeholder = error.localizedDescription
            playback = nil
        }
    }

    func playPause() async { await control { try await $0.playPause() } }
    func next() async { await control { try await $0.next() } }
    func previous() async { await control { try await $0.previous() } }

    private func control(_ action: (SpotifyBackend) async throws -> Void) async {
        do {
            try await action(backend)
            controlError = nil
        } catch {
            controlError = error.localizedDescription
        }
        // Spotify needs a moment before /me/player reflects the change.
        try? await Task.sleep(for: .milliseconds(400))
        await refresh()
    }

    private func loadArtwork(for state: SpotifyPlayback?) async {
        if Demo.active {
            artwork = Demo.spotifyArtwork
            return
        }
        guard let url = state?.artworkURL else {
            artwork = nil
            artworkURL = nil
            return
        }
        guard url != artworkURL else { return }
        artworkURL = url
        if let (data, _) = try? await URLSession.shared.data(from: url),
           let image = NSImage(data: data) {
            artwork = image
        } else {
            artwork = nil
        }
    }
}
