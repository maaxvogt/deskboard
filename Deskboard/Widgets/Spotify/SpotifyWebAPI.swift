import Foundation
import os

/// Playback state and transport controls via the Spotify Web API
/// (`/v1/me/player`). Shows whatever device the account is playing on; the
/// control endpoints require Spotify Premium.
struct SpotifyWebAPI: SpotifyBackend {
    private static let base = "https://api.spotify.com/v1/me/player"
    private let log = Logger(subsystem: "com.maxvogt.deskboard", category: "spotify")

    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: Response shape (only the fields the widget uses)

    struct PlayerState: Decodable {
        let is_playing: Bool
        let progress_ms: Int?
        let currently_playing_type: String?
        let item: Item?
    }

    struct Item: Decodable {
        struct Named: Decodable { let name: String }
        struct Image: Decodable { let url: String; let width: Int?; let height: Int? }
        struct Album: Decodable { let name: String; let images: [Image] }
        struct Show: Decodable { let name: String; let publisher: String? }

        let id: String?
        let name: String
        let duration_ms: Int
        // Tracks
        let artists: [Named]?
        let album: Album?
        // Podcast episodes
        let show: Show?
        let images: [Image]?
    }

    /// Picks the smallest image that is still at least 160 px wide (the widget shows ~84 pt).
    static func artworkURL(from images: [Item.Image]) -> URL? {
        let sorted = images.sorted { ($0.width ?? .max) < ($1.width ?? .max) }
        let pick = sorted.first { ($0.width ?? 0) >= 160 } ?? sorted.last
        return pick.flatMap { URL(string: $0.url) }
    }

    static func playback(from state: PlayerState, at date: Date) -> SpotifyPlayback? {
        guard let item = state.item else { return nil }
        let artist = item.artists?.map(\.name).joined(separator: ", ") ?? item.show?.publisher ?? ""
        let album = item.album?.name ?? item.show?.name ?? ""
        let images = item.album?.images ?? item.images ?? []
        return SpotifyPlayback(
            trackID: item.id ?? item.name,
            title: item.name,
            artist: artist,
            album: album,
            artworkURL: artworkURL(from: images),
            duration: TimeInterval(item.duration_ms) / 1000,
            position: TimeInterval(state.progress_ms ?? 0) / 1000,
            isPlaying: state.is_playing,
            fetchedAt: date)
    }

    // MARK: SpotifyBackend

    func fetch() async throws -> SpotifyPlayback? {
        let (data, status) = try await request("GET", "?additional_types=track,episode")
        guard status != 204, !data.isEmpty else { return nil } // nothing active
        let state = try JSONDecoder().decode(PlayerState.self, from: data)
        return Self.playback(from: state, at: Date())
    }

    func playPause() async throws {
        let (data, status) = try await request("GET", "")
        var playing = false
        if status != 204, !data.isEmpty {
            playing = (try? JSONDecoder().decode(PlayerState.self, from: data))?.is_playing ?? false
        }
        _ = try await request("PUT", playing ? "/pause" : "/play")
    }

    func next() async throws { _ = try await request("POST", "/next") }
    func previous() async throws { _ = try await request("POST", "/previous") }

    // MARK: Transport

    private func request(_ method: String, _ path: String) async throws -> (Data, Int) {
        let token = try await SpotifyAuth.shared.validAccessToken()
        var request = URLRequest(url: URL(string: Self.base + path)!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200...299:
            return (data, status)
        default:
            // Error bodies are {"error": {"status", "message", "reason"?}} — no user content.
            let body = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
            let message = body?["message"] as? String ?? ""
            let reason = body?["reason"] as? String ?? ""
            log.notice("\(method, privacy: .public) \(path, privacy: .public) -> \(status): \(reason, privacy: .public) \(message, privacy: .public)")
            switch status {
            case 401: throw APIError(message: "Spotify login expired — connect again in Settings")
            case 403 where reason == "PREMIUM_REQUIRED": throw APIError(message: "Controls need Spotify Premium")
            case 403: throw APIError(message: message.isEmpty ? "Spotify refused (\(reason))" : message)
            case 404: throw APIError(message: "No active Spotify device")
            case 429: throw APIError(message: "Spotify rate limit — retrying")
            default: throw APIError(message: message.isEmpty ? "Spotify error \(status)" : message)
            }
        }
    }
}
