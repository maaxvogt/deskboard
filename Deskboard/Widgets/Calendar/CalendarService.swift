import EventKit
import Foundation
import Observation

struct CalendarDay: Identifiable {
    let id: Date
    let date: Date
    let events: [EKEvent]
}

/// Upcoming events from the macOS calendar store (whatever accounts the
/// Calendar app has — iCloud, IONOS CalDAV, …).
@Observable
final class CalendarService {
    private(set) var days: [CalendarDay] = []
    private(set) var accessDenied = false

    private let store = EKEventStore()

    func refresh() async {
        let granted: Bool
        if #available(macOS 14.0, *) {
            granted = (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            granted = (try? await store.requestAccess(to: .event)) ?? false
        }
        guard granted else {
            accessDenied = true
            days = []
            return
        }
        accessDenied = false

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 7, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay || $0.endDate > Date() }
            .sorted { $0.startDate < $1.startDate }

        let grouped = Dictionary(grouping: events) { calendar.startOfDay(for: $0.startDate) }
        days = grouped.keys.sorted().map { day in
            CalendarDay(id: day, date: day, events: grouped[day] ?? [])
        }
    }
}
