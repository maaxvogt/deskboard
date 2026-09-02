import Foundation
import Observation
import os

struct GitHubPR: Identifiable {
    let id: Int
    var title: String
    var repo: String
    var number: Int
    var updated: Date?
}

struct GitHubEvent: Identifiable {
    let id: String
    var text: String
    var repo: String
    var date: Date?
}

@Observable
final class GitHubService {
    private(set) var openPRs: [GitHubPR] = []
    private(set) var events: [GitHubEvent] = []
    private(set) var error: String?
    private(set) var configured = false
    /// Set when the active token provably cannot see private repos (missing `repo` scope).
    private(set) var scopeHint: String?

    private var cachedCLIToken: String?
    private let log = Logger(subsystem: "com.maxvogt.deskboard", category: "github")

    func refresh() async {
        let settings = AppSettings.shared
        let settingsToken = settings.githubToken.isEmpty ? nil : settings.githubToken
        let cliToken = cliToken()
        guard let token = settingsToken ?? cliToken, !settings.githubUser.isEmpty else {
            configured = false
            return
        }
        configured = true
        do {
            var result = try await fetchAll(user: settings.githubUser, token: token)
            log.notice("""
                refresh via \(settingsToken != nil ? "settings" : "cli", privacy: .public) token \
                (\(Self.tokenKind(token), privacy: .public)): \(result.prs.count) PRs, \
                \(result.events.count) events, repo scope: \
                \(result.seesPrivateRepos.map(String.init) ?? "unknown", privacy: .public)
                """)
            // A Settings token without access to private repos gets HTTP 200 and
            // empty lists; retry once with the gh CLI login before showing nothing.
            if result.prs.isEmpty && result.events.isEmpty,
               settingsToken != nil, let cliToken, cliToken != settingsToken,
               let retry = try? await fetchAll(user: settings.githubUser, token: cliToken),
               !(retry.prs.isEmpty && retry.events.isEmpty) {
                result = retry
                log.notice("settings token returned nothing — using gh CLI token instead: \(retry.prs.count) PRs, \(retry.events.count) events")
            }
            openPRs = result.prs
            events = result.events
            error = nil
            if result.seesPrivateRepos == false {
                scopeHint = "Token lacks the 'repo' scope — PRs in private repos are hidden. "
                    + "Clear the token in Settings to use the gh CLI login instead."
            } else if result.prs.isEmpty && result.events.isEmpty && settingsToken != nil {
                scopeHint = "Nothing visible with the Settings token — it may lack access "
                    + "to your repos. Clear it in Settings to use the gh CLI login."
            } else {
                scopeHint = nil
            }
        } catch let apiError as GitHubAPIError {
            self.error = apiError.message
            log.notice("refresh failed: \(apiError.message, privacy: .public)")
        } catch {
            self.error = "GitHub unreachable"
            log.notice("refresh failed: \(error, privacy: .public)")
        }
    }

    private func fetchAll(
        user: String, token: String
    ) async throws -> (prs: [GitHubPR], events: [GitHubEvent], seesPrivateRepos: Bool?) {
        async let prs = fetchOpenPRs(user: user, token: token)
        async let evts = fetchEvents(user: user, token: token)
        let (prList, seesPrivateRepos) = try await prs
        return (prList, try await evts, seesPrivateRepos)
    }

    /// Token type by prefix ("gho_" = OAuth/CLI, "ghp_" = classic PAT,
    /// "gith" = fine-grained PAT). Never logs the token itself.
    private static func tokenKind(_ token: String) -> String {
        String(token.prefix(4))
    }

    /// Borrow the local `gh` CLI login.
    private func cliToken() -> String? {
        if let cached = cachedCLIToken { return cached }
        for ghPath in ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"]
        where FileManager.default.isExecutableFile(atPath: ghPath) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ghPath)
            process.arguments = ["auth", "token"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            guard (try? process.run()) != nil else { continue }
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { continue }
            let token = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty {
                cachedCLIToken = token
                return token
            }
        }
        return nil
    }

    struct GitHubAPIError: Error { let message: String }

    private func request(_ path: String, token: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.github.com" + path)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        return request
    }

    private func check(_ response: URLResponse) throws {
        guard let status = (response as? HTTPURLResponse)?.statusCode else { return }
        switch status {
        case 200...299: return
        case 401: throw GitHubAPIError(message: "Token invalid — check Settings")
        case 403, 429: throw GitHubAPIError(message: "Rate limited or missing token scope")
        default: throw GitHubAPIError(message: "GitHub error \(status)")
        }
    }

    /// `seesPrivateRepos` is nil when the token type does not report scopes
    /// (fine-grained PATs send no `X-OAuth-Scopes` header).
    private func fetchOpenPRs(
        user: String, token: String
    ) async throws -> (prs: [GitHubPR], seesPrivateRepos: Bool?) {
        let query = "is:pr+is:open+author:\(user)"
        let (data, response) = try await URLSession.shared.data(
            for: request("/search/issues?q=\(query)&sort=updated&per_page=6", token: token))
        try check(response)
        var seesPrivateRepos: Bool?
        if let scopes = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-OAuth-Scopes") {
            seesPrivateRepos = scopes
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .contains("repo")
        }

        struct SearchResult: Decodable {
            struct Item: Decodable {
                let id: Int
                let title: String
                let number: Int
                let repository_url: String
                let updated_at: String
            }
            let items: [Item]
        }
        let result = try JSONDecoder().decode(SearchResult.self, from: data)
        let prs = result.items.map {
            GitHubPR(
                id: $0.id,
                title: $0.title,
                repo: $0.repository_url.components(separatedBy: "/repos/").last ?? "",
                number: $0.number,
                updated: ISO8601DateFormatter().date(from: $0.updated_at)
            )
        }
        return (prs, seesPrivateRepos)
    }

    private func fetchEvents(user: String, token: String) async throws -> [GitHubEvent] {
        let (data, response) = try await URLSession.shared.data(
            for: request("/users/\(user)/events?per_page=15", token: token))
        try check(response)

        struct Event: Decodable {
            struct Repo: Decodable { let name: String }
            struct Payload: Decodable {
                struct Commit: Decodable { let message: String }
                let commits: [Commit]?
                let action: String?
                let ref_type: String?
                let ref: String?
            }
            let id: String
            let type: String
            let repo: Repo
            let payload: Payload
            let created_at: String
        }
        let decoded = try JSONDecoder().decode([Event].self, from: data)
        let formatter = ISO8601DateFormatter()

        return decoded.compactMap { event in
            let text: String?
            switch event.type {
            case "PushEvent":
                // The events API no longer ships commit messages in the payload;
                // fall back to the branch name when they are absent.
                let count = event.payload.commits?.count ?? 0
                let first = event.payload.commits?.first?.message.components(separatedBy: "\n").first ?? ""
                if first.isEmpty {
                    let branch = event.payload.ref?.components(separatedBy: "refs/heads/").last ?? ""
                    text = branch.isEmpty ? "Pushed" : "Pushed to \(branch)"
                } else {
                    text = count > 1 ? "\(count) commits — \(first)" : first
                }
            case "PullRequestEvent":
                text = "PR \(event.payload.action ?? "")"
            case "CreateEvent":
                text = "Created \(event.payload.ref_type ?? "ref")"
            case "IssuesEvent":
                text = "Issue \(event.payload.action ?? "")"
            case "ReleaseEvent":
                text = "Release \(event.payload.action ?? "")"
            default:
                text = nil
            }
            guard let text, !text.isEmpty else { return nil }
            return GitHubEvent(
                id: event.id,
                text: text,
                repo: event.repo.name.components(separatedBy: "/").last ?? event.repo.name,
                date: formatter.date(from: event.created_at)
            )
        }
    }
}
