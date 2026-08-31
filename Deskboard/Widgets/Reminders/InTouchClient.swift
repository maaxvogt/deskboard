import Foundation
import Observation

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
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    func refresh() async {
        guard !AppSettings.shared.inTouchKey.isEmpty else {
            configured = false
            return
        }
        configured = true
        do {
            let data = try await request("/api/addons/reminders/areas")
            let decoded = try JSONDecoder().decode(AreasResponse.self, from: data)
            guard decoded.success else {
                error = "API rejected the key"
                return
            }
            areas = decoded.areas ?? []
            error = nil
            if selectedArea == nil || !areas.contains(where: { $0.id == selectedArea }) {
                selectedArea = areas.first?.id
            } else {
                await loadItems()
            }
        } catch {
            self.error = "inTouch unreachable"
        }
    }

    func loadItems() async {
        guard let area = selectedArea else {
            items = []
            return
        }
        do {
            let data = try await request("/api/addons/reminders/items?area=\(area)")
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
        do {
            _ = try await request("/api/addons/reminders/items/\(item.id)", method: "PATCH", body: ["done": done])
        } catch {
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx].done = !done
            }
        }
    }

    func addItem(_ text: String) async {
        guard let area = selectedArea, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            _ = try await request("/api/addons/reminders/items", method: "POST", body: ["area": area, "text": text])
            await loadItems()
        } catch {
            self.error = "Could not add item"
        }
    }
}
