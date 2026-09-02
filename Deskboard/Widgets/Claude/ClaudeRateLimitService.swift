import Foundation
import Observation
import os

/// One rate-limit window as shown by `/usage` in Claude Code.
struct ClaudeRateLimit: Identifiable, Equatable {
    let id: String
    let title: String
    /// 0...100
    let percent: Double
    let resetsAt: Date?
}

/// Mirrors `/usage` in Claude Code: reads the Claude Code OAuth token from the
/// macOS Keychain (item written by Claude Code itself) and queries the same
/// endpoint the CLI uses. The endpoint is internal and undocumented — parsing
/// is deliberately lenient and every unknown shape is logged (never the token).
@Observable
final class ClaudeRateLimitService {
    private(set) var limits: [ClaudeRateLimit] = []
    private(set) var error: String?
    private(set) var fetchedAt: Date?

    private let log = Logger(subsystem: "com.maxvogt.deskboard", category: "usage")
    private var cachedToken: String?
    private var loggedShape = false

    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private static let keychainService = "Claude Code-credentials"

    func refresh() async {
        if Demo.active {
            limits = Demo.rateLimits
            fetchedAt = Date()
            error = nil
            return
        }
        do {
            let token = try await currentToken(forceReload: false)
            var (status, data) = try await fetch(token: token)
            if status == 401 {
                // Claude Code refreshes its token in the background — re-read it.
                let fresh = try await currentToken(forceReload: true)
                (status, data) = try await fetch(token: fresh)
            }
            guard status == 200 else {
                let body = String(decoding: data.prefix(300), as: UTF8.self)
                log.error("usage HTTP \(status): \(body, privacy: .public)")
                throw ServiceError.http(status)
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ServiceError.badResponse
            }
            if !loggedShape {
                loggedShape = true
                log.info("usage response keys: \(json.keys.sorted().joined(separator: ","), privacy: .public)")
            }
            limits = Self.parse(json)
            log.info("usage windows: \(self.limits.map { "\($0.title)=\(Int($0.percent))%" }.joined(separator: " | "), privacy: .public)")
            fetchedAt = Date()
            error = nil
        } catch let err as ServiceError {
            error = err.message
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Parsing

    /// Order matches `/usage`: session, week (all models), then model-scoped weeks.
    static func parse(_ json: [String: Any]) -> [ClaudeRateLimit] {
        var result: [ClaudeRateLimit] = []
        if let session = window(json["five_hour"], id: "five_hour", title: "Session") {
            result.append(session)
        }
        if let week = window(json["seven_day"], id: "seven_day", title: "Week · all") {
            result.append(week)
        }

        var scoped: [ClaudeRateLimit] = []
        if let limits = json["limits"] as? [[String: Any]] {
            for (index, limit) in limits.enumerated() {
                guard limit["kind"] as? String == "weekly_scoped",
                      let scope = limit["scope"] as? [String: Any],
                      let model = scope["model"] as? [String: Any],
                      let name = model["display_name"] as? String,
                      let percent = number(limit["percent"] ?? limit["utilization"]) else { continue }
                scoped.append(ClaudeRateLimit(
                    id: "scoped_\(index)_\(name)",
                    title: "Week · \(name)",
                    percent: percent,
                    resetsAt: date(limit["resets_at"])))
            }
        }
        if scoped.isEmpty {
            // Older response shape: fixed per-model windows.
            if let opus = window(json["seven_day_opus"], id: "seven_day_opus", title: "Week · Opus") {
                scoped.append(opus)
            }
            if let sonnet = window(json["seven_day_sonnet"], id: "seven_day_sonnet", title: "Week · Sonnet") {
                scoped.append(sonnet)
            }
        }
        result.append(contentsOf: scoped)
        return result
    }

    private static func window(_ value: Any?, id: String, title: String) -> ClaudeRateLimit? {
        guard let dict = value as? [String: Any],
              let percent = number(dict["utilization"] ?? dict["percent"]) else { return nil }
        return ClaudeRateLimit(id: id, title: title, percent: percent, resetsAt: date(dict["resets_at"]))
    }

    private static func number(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private static let isoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    /// Accepts "2026-09-02T15:00:00Z", "+00:00" offsets and any fraction length.
    private static func date(_ value: Any?) -> Date? {
        if let seconds = value as? Double { return Date(timeIntervalSince1970: seconds) }
        if let seconds = value as? Int { return Date(timeIntervalSince1970: Double(seconds)) }
        guard var s = value as? String else { return nil }
        // ISO8601DateFormatter only understands up to three fractional digits.
        if let dot = s.firstIndex(of: "."),
           let end = s[dot...].firstIndex(where: { $0 == "Z" || $0 == "+" || $0 == "-" }) {
            let fraction = s[s.index(after: dot)..<end]
            if fraction.count > 3 {
                s.replaceSubrange(dot..<end, with: "." + fraction.prefix(3))
            }
        }
        return isoFraction.date(from: s) ?? isoPlain.date(from: s)
    }

    // MARK: - Network

    private func fetch(token: String) async throws -> (Int, Data) {
        var request = URLRequest(url: Self.usageURL)
        request.timeoutInterval = 10
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (status, data)
    }

    // MARK: - Token

    private func currentToken(forceReload: Bool) async throws -> String {
        if !forceReload, let cached = cachedToken { return cached }
        let token = try await Task.detached(priority: .utility) { try Self.readKeychainToken() }.value
        cachedToken = token
        return token
    }

    /// Claude Code stores its login via the `security` CLI, so `security` is on
    /// the item's ACL and can read it back without a Keychain prompt.
    private static func readKeychainToken() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", keychainService, "-w"]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        do { try process.run() } catch { throw ServiceError.noToken }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ServiceError.noToken }

        let raw = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty else {
            throw ServiceError.noToken
        }
        if let expires = oauth["expiresAt"] as? Double, expires / 1000 < Date().timeIntervalSince1970 {
            throw ServiceError.expired
        }
        return token
    }

    enum ServiceError: Error {
        case noToken, expired, http(Int), badResponse

        var message: String {
            switch self {
            case .noToken: return "Not signed in to Claude Code"
            case .expired: return "Claude Code login expired — start a session to refresh"
            case .http(let status): return "Usage API error \(status)"
            case .badResponse: return "Unexpected usage response"
            }
        }
    }
}

extension ClaudeRateLimit {
    /// "resets 14:00", "resets tomorrow 02:00", "resets Thu 09:00".
    var resetLabel: String? {
        guard let resetsAt else { return nil }
        let time = resetsAt.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        let calendar = Calendar.current
        if calendar.isDateInToday(resetsAt) { return "resets \(time)" }
        if calendar.isDateInTomorrow(resetsAt) { return "resets tomorrow \(time)" }
        let day = resetsAt.formatted(.dateTime.weekday(.abbreviated))
        return "resets \(day) \(time)"
    }
}
