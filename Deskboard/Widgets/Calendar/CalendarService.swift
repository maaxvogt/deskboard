import AppKit
import EventKit
import Foundation
import Observation

/// What the widget needs from an event — decoupled from EKEvent so the list can
/// also be filled with sample data.
struct CalendarEntry: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: NSColor
}

struct CalendarDay: Identifiable {
    let id: Date
    let date: Date
    let events: [CalendarEntry]
}

/// Upcoming events from the macOS calendar store (whatever accounts the
/// Calendar app has — iCloud, CalDAV, …). Read-only.
@Observable
final class CalendarService {
    private(set) var days: [CalendarDay] = []
    private(set) var accessDenied = false

    private let store = EKEventStore()

    func refresh() async {
        if Demo.active {
            days = Self.group(Demo.calendarEntries)
            return
        }
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
        let entries = store.events(matching: predicate)
            .filter { !$0.isAllDay || $0.endDate > Date() }
            .map { event in
                CalendarEntry(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Untitled",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    color: event.calendar?.color ?? .gray)
            }
        days = Self.group(entries)
    }

    /// Sorts by start and groups into days.
    static func group(_ entries: [CalendarEntry]) -> [CalendarDay] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries.sorted { $0.start < $1.start }) {
            calendar.startOfDay(for: $0.start)
        }
        return grouped.keys.sorted().map { day in
            CalendarDay(id: day, date: day, events: grouped[day] ?? [])
        }
    }
}
