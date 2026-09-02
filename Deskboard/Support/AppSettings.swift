import Foundation
import Observation

/// App-wide configuration. Non-secret values live in UserDefaults,
/// credentials in the keychain. Singleton, observed by settings UI and widgets.
///
/// Every remote endpoint and account is empty until the user fills it in
/// under Settings (⌘,) — the app ships with no baked-in hosts or names.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    // MARK: Claude Status
    var claudeAPIBase: String {
        didSet { UserDefaults.standard.set(claudeAPIBase, forKey: "claudeAPIBase") }
    }
    var claudeToken: String {
        didSet { KeychainHelper.set(claudeToken, for: "claudeToken") }
    }

    // MARK: IMAP
    var imapHost: String { didSet { UserDefaults.standard.set(imapHost, forKey: "imapHost") } }
    var imapUser: String { didSet { UserDefaults.standard.set(imapUser, forKey: "imapUser") } }
    var imapPassword: String { didSet { KeychainHelper.set(imapPassword, for: "imapPassword") } }

    // MARK: GitHub
    var githubUser: String { didSet { UserDefaults.standard.set(githubUser, forKey: "githubUser") } }
    var githubToken: String { didSet { KeychainHelper.set(githubToken, for: "githubToken") } }

    // MARK: inTouch
    var inTouchAPIBase: String { didSet { UserDefaults.standard.set(inTouchAPIBase, forKey: "inTouchAPIBase") } }
    var inTouchKey: String { didSet { KeychainHelper.set(inTouchKey, for: "inTouchKey") } }

    // MARK: Spotify
    /// Client ID of the user's own Spotify developer app (PKCE, no secret).
    var spotifyClientID: String { didSet { UserDefaults.standard.set(spotifyClientID, forKey: "spotifyClientID") } }

    // MARK: Weather
    var weatherPlace: String { didSet { UserDefaults.standard.set(weatherPlace, forKey: "weatherPlace") } }

    // MARK: Appearance / window
    var appearance: Appearance { didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appearance") } }
    var startFullScreen: Bool { didSet { UserDefaults.standard.set(startFullScreen, forKey: "startFullScreen") } }
    /// Display the dashboard was last moved to (NSScreenNumber as string).
    var lastDisplayID: String? { didSet { UserDefaults.standard.set(lastDisplayID, forKey: "lastDisplayID") } }

    private init() {
        let d = UserDefaults.standard
        claudeAPIBase = d.string(forKey: "claudeAPIBase") ?? ""
        // Convenience: the claude-status hooks keep their token in
        // ~/.claude/settings.json (env.CLAUDE_STATUS_TOKEN) — use it as the
        // default so the widget works on first launch.
        claudeToken = KeychainHelper.get("claudeToken") ?? Self.claudeTokenFromClaudeSettings() ?? ""
        imapHost = d.string(forKey: "imapHost") ?? ""
        imapUser = d.string(forKey: "imapUser") ?? ""
        imapPassword = KeychainHelper.get("imapPassword") ?? ""
        githubUser = d.string(forKey: "githubUser") ?? ""
        githubToken = KeychainHelper.get("githubToken") ?? ""
        inTouchAPIBase = d.string(forKey: "inTouchAPIBase") ?? ""
        inTouchKey = KeychainHelper.get("inTouchKey") ?? ""
        spotifyClientID = d.string(forKey: "spotifyClientID") ?? ""
        weatherPlace = d.string(forKey: "weatherPlace") ?? ""
        // Demo launches pin the appearance and stay windowed; assignments in
        // init don't run didSet, so nothing is persisted.
        appearance = Demo.appearanceOverride
            ?? d.string(forKey: "appearance").flatMap(Appearance.init(rawValue:))
            ?? .auto
        startFullScreen = Demo.active ? false : (d.object(forKey: "startFullScreen") as? Bool ?? true)
        lastDisplayID = d.string(forKey: "lastDisplayID")
    }

    private static func claudeTokenFromClaudeSettings() -> String? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let env = root["env"] as? [String: Any],
              let token = env["CLAUDE_STATUS_TOKEN"] as? String, !token.isEmpty else {
            return nil
        }
        return token
    }
}
