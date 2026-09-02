import AppKit
import CryptoKit
import Foundation
import Observation
import os

/// Spotify login (Authorization Code + PKCE) and token lifecycle.
///
/// The user registers their own app in the Spotify Developer Dashboard and pastes
/// the Client ID into Settings; there is no client secret. The refresh token is the
/// only thing persisted (Keychain), access tokens live in memory for their hour.
/// The browser sends the user back via the `deskboard://spotify-callback` URL
/// scheme, delivered by the app delegate to `handleCallback`.
@Observable
final class SpotifyAuth {
    static let shared = SpotifyAuth()

    static let redirectURI = "deskboard://spotify-callback"
    static let scopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing"

    private static let accountsBase = "https://accounts.spotify.com"
    private static let refreshTokenKey = "spotifyRefreshToken"

    private(set) var isConnected: Bool
    /// Last login/refresh problem, for Settings.
    private(set) var lastError: String?

    struct AuthError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private let log = Logger(subsystem: "com.maxvogt.deskboard", category: "spotify")
    private var accessToken: String?
    private var accessTokenExpiry = Date.distantPast
    private var refreshTask: Task<String, Error>?
    // Only set while a login is in flight.
    private var pendingVerifier: String?
    private var pendingState: String?

    private init() {
        isConnected = KeychainHelper.get(Self.refreshTokenKey) != nil
    }

    var clientID: String { AppSettings.shared.spotifyClientID.trimmingCharacters(in: .whitespacesAndNewlines) }

    // MARK: Login

    /// Opens the Spotify consent page in the default browser.
    func beginLogin() {
        guard !clientID.isEmpty else {
            lastError = "Enter your Client ID first"
            return
        }
        let verifier = Self.randomString(64)
        let state = Self.randomString(16)
        pendingVerifier = verifier
        pendingState = state
        lastError = nil

        var components = URLComponents(string: Self.accountsBase + "/authorize")!
        components.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: Self.redirectURI),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: Self.challenge(for: verifier)),
            .init(name: "scope", value: Self.scopes),
            .init(name: "state", value: state),
        ]
        log.info("Opening Spotify authorize page")
        NSWorkspace.shared.open(components.url!)
    }

    /// Entry point for `deskboard://spotify-callback?code=…&state=…`.
    func handleCallback(_ url: URL) {
        guard url.scheme == "deskboard", url.host == "spotify-callback" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        guard let state = value("state"), state == pendingState, let verifier = pendingVerifier else {
            log.notice("Callback ignored: state mismatch or no login in flight")
            lastError = "Login callback did not match — try again"
            return
        }
        pendingState = nil
        pendingVerifier = nil
        if let error = value("error") {
            log.notice("Authorization denied: \(error, privacy: .public)")
            lastError = "Spotify said: \(error)"
            return
        }
        guard let code = value("code") else {
            lastError = "Callback without code"
            return
        }
        Task { await exchange(code: code, verifier: verifier) }
    }

    private func exchange(code: String, verifier: String) async {
        do {
            let token = try await tokenRequest([
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": Self.redirectURI,
                "client_id": clientID,
                "code_verifier": verifier,
            ])
            guard let refresh = token.refresh_token else { throw AuthError(message: "No refresh token in response") }
            KeychainHelper.set(refresh, for: Self.refreshTokenKey)
            store(token)
            isConnected = true
            lastError = nil
            log.info("Connected to Spotify")
        } catch {
            lastError = error.localizedDescription
            log.notice("Token exchange failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func disconnect() {
        KeychainHelper.delete(Self.refreshTokenKey)
        accessToken = nil
        accessTokenExpiry = .distantPast
        isConnected = false
        lastError = nil
        log.info("Disconnected from Spotify")
    }

    // MARK: Access token

    /// A valid access token, refreshing when the cached one is (almost) expired.
    func validAccessToken() async throws -> String {
        if let accessToken, accessTokenExpiry > Date().addingTimeInterval(60) { return accessToken }
        if let refreshTask { return try await refreshTask.value }
        let task = Task<String, Error> { [self] in
            defer { self.refreshTask = nil }
            guard let refresh = KeychainHelper.get(Self.refreshTokenKey) else {
                throw AuthError(message: "Connect Spotify in Settings")
            }
            do {
                let token = try await tokenRequest([
                    "grant_type": "refresh_token",
                    "refresh_token": refresh,
                    "client_id": clientID,
                ])
                if let rotated = token.refresh_token { KeychainHelper.set(rotated, for: Self.refreshTokenKey) }
                store(token)
                return token.access_token
            } catch let error as AuthError where error.message.hasPrefix("invalid_grant") {
                // Revoked or expired refresh token: the user has to log in again.
                disconnect()
                lastError = "Spotify login expired — connect again in Settings"
                throw AuthError(message: lastError!)
            }
        }
        refreshTask = task
        return try await task.value
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let expires_in: Int
        let refresh_token: String?
    }

    private func store(_ token: TokenResponse) {
        accessToken = token.access_token
        accessTokenExpiry = Date().addingTimeInterval(TimeInterval(token.expires_in))
    }

    private func tokenRequest(_ fields: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: Self.accountsBase + "/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode(fields).data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(status) else {
            // Error bodies are {"error": "...", "error_description": "..."} — no secrets.
            let body = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let code = body["error"] as? String ?? "HTTP \(status)"
            let description = body["error_description"] as? String ?? ""
            log.notice("Token endpoint -> \(status): \(code, privacy: .public) \(description, privacy: .public)")
            throw AuthError(message: description.isEmpty ? code : "\(code): \(description)")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    // MARK: PKCE helpers

    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func randomString(_ length: Int) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return String((0..<length).map { _ in alphabet.randomElement()! })
    }

    private static func formEncode(_ fields: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return fields.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
        }.joined(separator: "&")
    }
}
