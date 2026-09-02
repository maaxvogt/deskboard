import AppKit
import Foundation

/// Demo mode for screenshots and UI work. `Deskboard --demo` makes every widget
/// show fixed sample data and never touches the network, the keychain, the
/// calendar store or external tools. `--appearance=light|dark|darkColor` pins
/// the appearance for that launch only (nothing is written to UserDefaults).
///
/// The flag is simply never set in normal use, so nothing here is compiled out.
enum Demo {
    static let active = ProcessInfo.processInfo.arguments.contains("--demo")

    static var appearanceOverride: Appearance? {
        ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("--appearance=") }
            .flatMap { Appearance(rawValue: String($0.dropFirst("--appearance=".count))) }
    }

    // MARK: - Time helpers (relative to now, so screenshots never look stale)

    private static var startOfDay: Date { Calendar.current.startOfDay(for: Date()) }

    /// `minutes` ago, but never before today started (the Claude widget only shows today).
    private static func ago(minutes: Double) -> Date {
        max(startOfDay.addingTimeInterval(60), Date().addingTimeInterval(-minutes * 60))
    }

    private static func inHours(_ hours: Double) -> Date { Date().addingTimeInterval(hours * 3600) }

    private static func day(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let calendar = Calendar.current
        let base = calendar.date(byAdding: .day, value: offset, to: startOfDay)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }

    private static func millis(_ date: Date) -> Double { date.timeIntervalSince1970 * 1000 }

    // MARK: - Today / weather

    static let weather = WeatherSnapshot(
        place: "Berlin", temperature: 21.4, todayMin: 14.2, todayMax: 24.8, weatherCode: 2)

    // MARK: - System

    static let system = SystemSnapshot(
        cpuPercent: 23,
        memUsed: 18 * 1024 * 1024 * 1024 + 650 * 1024 * 1024,
        memTotal: 36 * 1024 * 1024 * 1024,
        diskFree: 412_000_000_000,
        diskTotal: 1_000_000_000_000,
        netDownBps: 1_540_000,
        netUpBps: 220_000)

    // MARK: - Batteries

    static let batteries = [
        DeviceBattery(id: "mac", name: "MacBook Pro", percent: 84, charging: false),
        DeviceBattery(id: "ipad", name: "iPad Pro", percent: 62, charging: true),
        DeviceBattery(id: "iphone", name: "iPhone", percent: 91, charging: false),
    ]

    // MARK: - Claude Code

    static var claudeTasks: [ClaudeTask] {
        func task(_ id: String, _ title: String, _ status: String, _ project: String, minutesAgo: Double) -> ClaudeTask {
            let updated = ago(minutes: minutesAgo)
            return ClaudeTask(
                id: id, title: title, status: status, source: "claude-code", project: project,
                created_at: millis(updated.addingTimeInterval(-1800)), updated_at: millis(updated),
                completed_at: ["done", "failed"].contains(status) ? millis(updated) : nil)
        }
        return [
            task("t1", "Refactor auth middleware for the API worker", "running", "status-api", minutesAgo: 1),
            task("t2", "Add pagination to the orders endpoint", "waiting", "shop-backend", minutesAgo: 6),
            task("t3", "Write the migration guide for v2 settings", "running", "docs", minutesAgo: 0.5),
            task("t4", "Fix flaky calendar test on CI", "done", "deskboard", minutesAgo: 48),
            task("t5", "Rename theme tokens to match the design system", "done", "deskboard", minutesAgo: 95),
            task("t6", "Investigate IMAP timeout after network change", "failed", "deskboard", minutesAgo: 140),
        ]
    }

    static var rateLimits: [ClaudeRateLimit] {
        [
            ClaudeRateLimit(id: "five_hour", title: "Session", percent: 34, resetsAt: inHours(2.3)),
            ClaudeRateLimit(id: "seven_day", title: "Week · all", percent: 12, resetsAt: inHours(70)),
            ClaudeRateLimit(id: "scoped", title: "Week · Fable", percent: 8, resetsAt: inHours(70)),
        ]
    }

    static let usage = ClaudeUsage(
        inputTokens: 120_000, outputTokens: 86_300,
        cacheReadTokens: 3_600_000, cacheCreationTokens: 480_000, sessions: 6)

    // MARK: - Calendar

    static var calendarEntries: [CalendarEntry] {
        func entry(_ title: String, _ start: Date, _ end: Date, allDay: Bool = false, _ color: NSColor) -> CalendarEntry {
            CalendarEntry(id: title, title: title, start: start, end: end, isAllDay: allDay, color: color)
        }
        return [
            entry("Team stand-up", day(0, 9, 30), day(0, 9, 45), .systemBlue),
            entry("Design review: dashboard v2", day(0, 14), day(0, 15), .systemPurple),
            entry("Dentist", day(1, 8, 15), day(1, 9), .systemRed),
            entry("1:1 with Sarah", day(1, 11), day(1, 11, 30), .systemBlue),
            entry("Release planning", day(2, 0), day(3, 0), allDay: true, .systemOrange),
            entry("Lunch with Jonas", day(3, 12, 30), day(3, 13, 30), .systemGreen),
        ]
    }

    // MARK: - Reminders

    static let reminderAreas = [
        ReminderAreaDTO(id: "groceries", name: "Groceries", color_index: 2, item_count: 7, open_count: 5),
        ReminderAreaDTO(id: "home", name: "Home", color_index: 4, item_count: 3, open_count: 2),
        ReminderAreaDTO(id: "work", name: "Work", color_index: 0, item_count: 4, open_count: 3),
    ]

    static func reminderItems(for area: String) -> [ReminderItemDTO] {
        func item(_ id: Int, _ text: String, done: Bool = false, heading: Bool = false) -> ReminderItemDTO {
            ReminderItemDTO(id: id, area: area, type: heading ? "heading" : "text",
                            heading_level: heading ? 1 : nil, text: text, done: done, sort: id)
        }
        switch area {
        case "groceries":
            return [
                item(1, "Oat milk", done: true), item(2, "Coffee beans"), item(3, "Tomatoes"),
                item(4, "Bread", done: true), item(5, "Weekend", heading: true),
                item(6, "Charcoal for the grill"), item(7, "Lemons"),
            ]
        case "home":
            return [item(1, "Water the plants"), item(2, "Book chimney sweep", done: true), item(3, "Replace hallway bulb")]
        default:
            return [
                item(1, "Send invoice to Acme"), item(2, "Review PR #2"),
                item(3, "Prepare Thursday demo", done: true), item(4, "Renew domain"),
            ]
        }
    }

    // MARK: - Mail

    static var mails: [MailSummary] {
        [
            MailSummary(id: 6, subject: "Re: Dashboard layout feedback", from: "Sarah Lindqvist", date: ago(minutes: 25), unread: true),
            MailSummary(id: 5, subject: "[deskboard] PR #2: Appearance modes", from: "GitHub", date: ago(minutes: 70), unread: true),
            MailSummary(id: 4, subject: "Your certificate expires in 30 days", from: "Apple Developer", date: Date().addingTimeInterval(-3 * 3600), unread: false),
            MailSummary(id: 3, subject: "Lunch on Friday?", from: "Jonas Weber", date: day(-1, 17, 40), unread: false),
            MailSummary(id: 2, subject: "API changelog — September", from: "Open-Meteo", date: day(-2, 9, 5), unread: false),
            MailSummary(id: 1, subject: "Weekly usage summary", from: "Cloudflare", date: day(-3, 6, 0), unread: false),
        ]
    }

    // MARK: - GitHub

    static let pullRequests = [
        GitHubPR(id: 1, title: "Appearance modes and native full screen", repo: "deskboard", number: 2, updated: Date().addingTimeInterval(-2 * 3600)),
        GitHubPR(id: 2, title: "Add reminders addon endpoint", repo: "notes-backend", number: 41, updated: Date().addingTimeInterval(-26 * 3600)),
        GitHubPR(id: 3, title: "Heal stale locks on begin", repo: "status-api", number: 17, updated: Date().addingTimeInterval(-50 * 3600)),
    ]

    static let githubEvents = [
        GitHubEvent(id: "e1", text: "3 commits — Appearance modes (Light/Dark/Dark Color)", repo: "deskboard", date: Date().addingTimeInterval(-2 * 3600)),
        GitHubEvent(id: "e2", text: "Pushed to main", repo: "status-api", date: Date().addingTimeInterval(-5 * 3600)),
        GitHubEvent(id: "e3", text: "PR opened", repo: "notes-backend", date: Date().addingTimeInterval(-26 * 3600)),
        GitHubEvent(id: "e4", text: "Created branch", repo: "deskboard", date: Date().addingTimeInterval(-30 * 3600)),
        GitHubEvent(id: "e5", text: "Release published", repo: "status-api", date: Date().addingTimeInterval(-3 * 86400)),
    ]
}
