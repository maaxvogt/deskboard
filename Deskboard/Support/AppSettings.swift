import Foundation
import Observation

/// App-wide configuration. Non-secret values live in UserDefaults,
/// credentials in the keychain. Singleton, observed by settings UI and widgets.
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

    // MARK: IMAP (IONOS)
    var imapHost: String { didSet { UserDefaults.standard.set(imapHost, forKey: "imapHost") } }
    var imapUser: String { didSet { UserDefaults.standard.set(imapUser, forKey: "imapUser") } }
    var imapPassword: String { didSet { KeychainHelper.set(imapPassword, for: "imapPassword") } }

    // MARK: GitHub
    var githubUser: String { didSet { UserDefaults.standard.set(githubUser, forKey: "githubUser") } }
    var githubToken: String { didSet { KeychainHelper.set(githubToken, for: "githubToken") } }

    // MARK: inTouch
    var inTouchAPIBase: String { didSet { UserDefaults.standard.set(inTouchAPIBase, forKey: "inTouchAPIBase") } }
    var inTouchKey: String { didSet { KeychainHelper.set(inTouchKey, for: "inTouchKey") } }

    // MARK: Weather
    var weatherPlace: String { didSet { UserDefaults.standard.set(weatherPlace, forKey: "weatherPlace") } }

    private init() {
        let d = UserDefaults.standard
        claudeAPIBase = d.string(forKey: "claudeAPIBase") ?? "https://claude-status-api.mavoxgt.workers.dev"
        claudeToken = KeychainHelper.get("claudeToken") ?? ""
        imapHost = d.string(forKey: "imapHost") ?? "imap.ionos.de"
        imapUser = d.string(forKey: "imapUser") ?? ""
        imapPassword = KeychainHelper.get("imapPassword") ?? ""
        githubUser = d.string(forKey: "githubUser") ?? "maaxvogt"
        githubToken = KeychainHelper.get("githubToken") ?? ""
        inTouchAPIBase = d.string(forKey: "inTouchAPIBase") ?? "https://intouch-backend.mavoxgt.workers.dev"
        inTouchKey = KeychainHelper.get("inTouchKey") ?? ""
        weatherPlace = d.string(forKey: "weatherPlace") ?? ""
    }
}
