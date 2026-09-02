import Foundation
import Observation
import os

// Mirrors the inTouch reminders addon (backend/src/api/addons/reminders.js):
// plaintext mirror of reminder areas the user exposed per-area in the app.
struct ReminderAreaDTO: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var color_index: Int
    var item_count: Int
    var open_count: Int
}

struct ReminderItemDTO: Codable, Identifiable, Equatable {
    let id: Int
    var area: String
    var type: String // text | heading
    var heading_level: Int?
    var text: String
    var done: Bool
    var sort: Int
}

@Observable
final class InTouchClient {
    private(set) var areas: [ReminderAreaDTO] = []
    private(set) var items: [ReminderItemDTO] = []
    private(set) var error: String?
    private(set) var configured = false
    var selectedArea: String? {
        didSet { Task { await loadItems() } }
    }

    private struct AreasResponse: Codable { let success: Bool; let areas: [ReminderAreaDTO]? }
    private struct ItemsResponse: Codable { let success: Bool; let items: [ReminderItemDTO]? }

    struct APIStatusError: Error { let message: String }

    private let log = Logger(subsystem: "com.maxvogt.deskboard", category: "intouch")

    private func request(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> Data {
        let settings = AppSettings.shared
        guard let url = URL(string: settings.inTouchAPIBase + path) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(settings.inTouchKey, forHTTPHeaderField: "X-API-Key")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        switch (response as? HTTPURLResponse)?.statusCode ?? 200 {
        case 200...299: break
        case let status:
            // Error bodies are JSON without user content — safe to log verbatim.
            let bodyText = String(decoding: data.prefix(500), as: UTF8.self)
            log.notice("\(method, privacy: .public) \(path, privacy: .public) -> \(status): \(bodyText, privacy: .public)")
            let serverMessage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error"] as? String }
            switch status {
            case 401, 403: throw APIStatusError(message: "API key rejected — check Settings")
            case 404 where method == "DELETE": throw APIStatusError(message: "Backend does not support clearing completed items yet")
            case 404: throw APIStatusError(message: "Reminders addon not available yet on the backend")
            default: throw APIStatusError(message: serverMessage ?? "inTouch error \(status)")
            }
        }
        return data
    }

    func refresh() async {
        if Demo.active {
            configured = true
            areas = Demo.reminderAreas
            error = nil
            if selectedArea == nil { selectedArea = areas.first?.id } else { await loadItems() }
            return
        }
        guard !AppSettings.shared.inTouchKey.isEmpty, !AppSettings.shared.inTouchAPIBase.isEmpty else {
            configured = false
            return
        }
        configured = true
        do {
            let data = try await request("/api/addons/reminders/areas")
            let decoded = try JSONDecoder().decode(AreasResponse.self, from: data)
            guard decoded.success else {
                error = "Unexpected API response"
                return
            }
            areas = decoded.areas ?? []
            error = nil
            if selectedArea == nil || !areas.contains(where: { $0.id == selectedArea }) {
                selectedArea = areas.first?.id
            } else {
                await loadItems()
            }
        } catch let status as APIStatusError {
            self.error = status.message
        } catch {
            self.error = "inTouch unreachable"
        }
    }

    func loadItems() async {
        guard let area = selectedArea else {
            items = []
            return
        }
        if Demo.active {
            items = Demo.reminderItems(for: area)
            return
        }
        let safeArea = area.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        do {
            let data = try await request("/api/addons/reminders/items?area=\(safeArea)")
            let decoded = try JSONDecoder().decode(ItemsResponse.self, from: data)
            if decoded.success {
                items = (decoded.items ?? []).sorted { $0.sort < $1.sort }
            }
        } catch {
            // Keep the last list; refresh() surfaces connectivity problems.
        }
    }

    func setDone(_ item: ReminderItemDTO, done: Bool) async {
        // Optimistic: flip locally, roll back if the call fails.
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].done = done
        }
        if Demo.active { return }
        do {
            _ = try await request("/api/addons/reminders/items/\(item.id)", method: "PATCH", body: ["done": done])
        } catch {
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx].done = !done
            }
            // Item IDs churn when the app pushes a fresh snapshot; a 404 here
            // usually means our list is stale — resync instead of just rolling back.
            await loadItems()
        }
    }

    /// Number of ticked-off todos in the current list (headings never count).
    var doneCount: Int { items.filter { $0.type == "text" && $0.done }.count }

    /// "Clear completed" like in the inTouch app: removes every ticked-off todo of
    /// the selected area; the app deletes them on its next sync.
    func deleteDone() async {
        guard let area = selectedArea, doneCount > 0 else { return }
        let before = items
        items.removeAll { $0.type == "text" && $0.done }
        if Demo.active { return }
        let safeArea = area.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        do {
            _ = try await request("/api/addons/reminders/items?area=\(safeArea)&done=true", method: "DELETE")
            await loadItems()
        } catch let status as APIStatusError {
            items = before
            self.error = status.message
        } catch {
            items = before
            self.error = "Could not delete completed items"
        }
    }

    func addItem(_ text: String) async {
        guard let area = selectedArea, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if Demo.active {
            items.append(ReminderItemDTO(id: (items.map(\.id).max() ?? 0) + 1, area: area, type: "text",
                                         heading_level: nil, text: text, done: false, sort: items.count + 1))
            return
        }
        do {
            _ = try await request("/api/addons/reminders/items", method: "POST", body: ["area": area, "text": text])
            await loadItems()
        } catch {
            self.error = "Could not add item"
        }
    }
}
