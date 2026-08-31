import Foundation
import Observation
import UserNotifications

// Mirrors the claude-status-api contract (see Claude Status repo, root CLAUDE.md).
struct ClaudeTask: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var status: String // queued | running | waiting | done | failed
    var source: String
    var project: String?
    var created_at: Double
    var updated_at: Double
    var completed_at: Double?

    var updatedDate: Date { Date(timeIntervalSince1970: updated_at / 1000) }
    var isActive: Bool { ["queued", "running", "waiting"].contains(status) }
}

/// REST + WebSocket client for the claude-status-api worker. Loads the task
/// list once, then applies live events from /api/stream; falls back to
/// periodic refetches while the socket is down.
@Observable
final class ClaudeStatusClient {
    private(set) var tasks: [ClaudeTask] = []
    private(set) var connected = false
    private(set) var error: String?

    private var socket: URLSessionWebSocketTask?
    private var running = false

    /// Only today's sessions are shown, per design.
    var active: [ClaudeTask] {
        tasks
            .filter { $0.isActive && Calendar.current.isDateInToday($0.updatedDate) }
            .sorted { $0.updated_at > $1.updated_at }
    }

    /// Sessions finished today, newest first.
    var recent: [ClaudeTask] {
        tasks
            .filter { !$0.isActive && Calendar.current.isDateInToday($0.updatedDate) }
            .sorted { $0.updated_at > $1.updated_at }
    }

    /// Manual status override from the dashboard (context menu on a row).
    func setStatus(_ task: ClaudeTask, to status: String) async {
        let settings = AppSettings.shared
        guard let url = URL(string: settings.claudeAPIBase + "/api/tasks/\(task.id)") else { return }
        // Optimistic; the WebSocket broadcast confirms (or a refetch corrects).
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].status = status
            tasks[idx].updated_at = Date().timeIntervalSince1970 * 1000
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(settings.claudeToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["status": status])
        _ = try? await URLSession.shared.data(for: request)
    }

    func start() async {
        guard !running else { return }
        running = true
        await refetch()
        while running {
            await runSocket()
            connected = false
            guard running else { break }
            // Socket dropped: refetch to close any gap, retry after a pause.
            try? await Task.sleep(for: .seconds(5))
            await refetch()
        }
    }

    func stop() {
        running = false
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    func refetch() async {
        let settings = AppSettings.shared
        guard !settings.claudeToken.isEmpty, let url = URL(string: settings.claudeAPIBase + "/api/tasks?filter=all") else {
            error = "No API token configured"
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(settings.claudeToken)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                error = "API error \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                return
            }
            // The endpoint returns either a bare array or {tasks:[...]}.
            if let list = try? JSONDecoder().decode([ClaudeTask].self, from: data) {
                tasks = list
            } else {
                struct Wrapper: Codable { let tasks: [ClaudeTask] }
                tasks = try JSONDecoder().decode(Wrapper.self, from: data).tasks
            }
            error = nil
        } catch {
            self.error = "API unreachable"
        }
    }

    // MARK: WebSocket

    private struct StreamEvent: Codable {
        let type: String
        let task: ClaudeTask?
    }

    private func runSocket() async {
        let settings = AppSettings.shared
        guard !settings.claudeToken.isEmpty else {
            try? await Task.sleep(for: .seconds(10))
            return
        }
        let base = settings.claudeAPIBase
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        guard let url = URL(string: base + "/api/stream?token=\(settings.claudeToken)") else { return }

        let task = URLSession.shared.webSocketTask(with: url)
        socket = task
        task.resume()
        connected = true

        let pinger = Task {
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(30))
                task.send(.string("ping")) { _ in }
            }
        }
        defer { pinger.cancel() }

        while running {
            do {
                let message = try await task.receive()
                if case .string(let text) = message {
                    handle(text)
                }
            } catch {
                return
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let event = try? JSONDecoder().decode(StreamEvent.self, from: data),
              let task = event.task else { return }
        switch event.type {
        case "task.created":
            if !tasks.contains(where: { $0.id == task.id }) { tasks.append(task) }
        case "task.updated":
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                let previous = tasks[idx].status
                tasks[idx] = task
                // Notify only when a session starts NEEDING the user — a live
                // transition into "waiting" — never on other status changes.
                if task.status == "waiting", previous == "running" || previous == "queued" {
                    ClaudeNotifier.notifyNeedsInput(title: task.title)
                }
            } else {
                tasks.append(task)
            }
        case "task.deleted":
            tasks.removeAll { $0.id == task.id }
        default:
            break
        }
    }
}

/// Local macOS notifications for Claude sessions that wait for the user.
enum ClaudeNotifier {
    private static var authorizationRequested = false

    static func notifyNeedsInput(title: String) {
        let center = UNUserNotificationCenter.current()
        if !authorizationRequested {
            authorizationRequested = true
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        let content = UNMutableNotificationContent()
        content.title = "Claude Code needs your input"
        content.body = title
        content.sound = .default
        center.add(UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        ))
    }
}
