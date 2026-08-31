import Foundation
import Observation

struct ClaudeUsage: Equatable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var sessions: Int = 0

    var totalIn: Int { inputTokens + cacheReadTokens + cacheCreationTokens }
}

/// Sums today's token usage from the local Claude Code transcripts
/// (~/.claude/projects/*/*.jsonl). Every assistant turn carries a
/// message.usage block; entries are deduplicated by message id.
@Observable
final class ClaudeUsageService {
    private(set) var usage = ClaudeUsage()

    func refresh() async {
        let computed = await Task.detached(priority: .utility) { Self.computeToday() }.value
        usage = computed
    }

    private static func computeToday() -> ClaudeUsage {
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        var result = ClaudeUsage()
        var seenMessageIds = Set<String>()

        let projectDirs = (try? FileManager.default.contentsOfDirectory(
            at: projectsDir, includingPropertiesForKeys: nil)) ?? []
        for projectDir in projectDirs {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: projectDir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for file in files where file.pathExtension == "jsonl" {
                // Only files touched today can contain today's turns.
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                guard modified >= startOfDay else { continue }
                guard let data = try? Data(contentsOf: file) else { continue }

                var sessionCounted = false
                for line in data.split(separator: UInt8(ascii: "\n")) {
                    // Cheap pre-filter before JSON parsing.
                    guard line.count > 20, line.range(of: Data("\"usage\"".utf8)) != nil else { continue }
                    guard let entry = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                          entry["type"] as? String == "assistant",
                          let message = entry["message"] as? [String: Any],
                          let usage = message["usage"] as? [String: Any] else { continue }

                    // Timestamps are ISO 8601 UTC ("2026-08-31T14:07:31.686Z").
                    if let ts = entry["timestamp"] as? String,
                       let date = parseISO(ts), date < startOfDay { continue }

                    if let id = message["id"] as? String {
                        guard seenMessageIds.insert(id).inserted else { continue }
                    }

                    result.inputTokens += usage["input_tokens"] as? Int ?? 0
                    result.outputTokens += usage["output_tokens"] as? Int ?? 0
                    result.cacheReadTokens += usage["cache_read_input_tokens"] as? Int ?? 0
                    result.cacheCreationTokens += usage["cache_creation_input_tokens"] as? Int ?? 0
                    sessionCounted = true
                }
                if sessionCounted { result.sessions += 1 }
            }
        }
        return result
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoFormatterNoFraction = ISO8601DateFormatter()

    private static func parseISO(_ string: String) -> Date? {
        isoFormatter.date(from: string) ?? isoFormatterNoFraction.date(from: string)
    }
}

enum TokenFormat {
    static func short(_ count: Int) -> String {
        switch count {
        case ..<1_000: return "\(count)"
        case ..<1_000_000: return String(format: "%.1fK", Double(count) / 1_000)
        default: return String(format: "%.1fM", Double(count) / 1_000_000)
        }
    }
}
