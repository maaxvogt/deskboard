import Foundation
import Observation

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

    func refresh() async {
        let settings = AppSettings.shared
        guard !settings.githubToken.isEmpty, !settings.githubUser.isEmpty else {
            configured = false
            return
        }
        configured = true
        do {
            async let prs = fetchOpenPRs(user: settings.githubUser, token: settings.githubToken)
            async let evts = fetchEvents(user: settings.githubUser, token: settings.githubToken)
            openPRs = try await prs
            events = try await evts
            error = nil
        } catch {
            self.error = "GitHub unreachable"
        }
    }

    private func request(_ path: String, token: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.github.com" + path)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        return request
    }

    private func fetchOpenPRs(user: String, token: String) async throws -> [GitHubPR] {
        let query = "is:pr+is:open+author:\(user)"
        let (data, _) = try await URLSession.shared.data(
            for: request("/search/issues?q=\(query)&sort=updated&per_page=6", token: token))

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
        return result.items.map {
            GitHubPR(
                id: $0.id,
                title: $0.title,
                repo: $0.repository_url.components(separatedBy: "/repos/").last ?? "",
                number: $0.number,
                updated: ISO8601DateFormatter().date(from: $0.updated_at)
            )
        }
    }

    private func fetchEvents(user: String, token: String) async throws -> [GitHubEvent] {
        let (data, _) = try await URLSession.shared.data(
            for: request("/users/\(user)/events?per_page=15", token: token))

        struct Event: Decodable {
            struct Repo: Decodable { let name: String }
            struct Payload: Decodable {
                struct Commit: Decodable { let message: String }
                let commits: [Commit]?
                let action: String?
                let ref_type: String?
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
                let count = event.payload.commits?.count ?? 0
                let first = event.payload.commits?.first?.message.components(separatedBy: "\n").first ?? ""
                text = count > 1 ? "\(count) commits — \(first)" : first
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
