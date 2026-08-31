import EventKit
import SwiftUI

struct CalendarWidget: View {
    @State private var service = CalendarService()

    var body: some View {
        WidgetCard("Calendar") {
            if service.accessDenied {
                WidgetPlaceholder(text: "Calendar access denied — allow it in System Settings → Privacy.")
            } else if service.days.isEmpty {
                WidgetPlaceholder(text: "No events in the next 7 days")
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(service.days) { day in
                            daySection(day)
                        }
                    }
                }
            }
        }
        .task {
            await service.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                await service.refresh()
            }
        }
    }

    private func daySection(_ day: CalendarDay) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dayLabel(day.date))
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(Theme.faint)
            ForEach(day.events, id: \.eventIdentifier) { event in
                eventRow(event)
            }
        }
    }

    private func eventRow(_ event: EKEvent) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(event.calendar?.color ?? .gray))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title ?? "Untitled")
                    .font(Theme.bodyMedium)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(timeLabel(event))
                    .font(Theme.caption)
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "TODAY" }
        if Calendar.current.isDateInTomorrow(date) { return "TOMORROW" }
        return date.formatted(.dateTime.weekday(.wide).day().month()).uppercased()
    }

    private func timeLabel(_ event: EKEvent) -> String {
        if event.isAllDay { return "All day" }
        let start = event.startDate.formatted(date: .omitted, time: .shortened)
        let end = event.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
}
