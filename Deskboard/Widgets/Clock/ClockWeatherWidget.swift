import SwiftUI

struct ClockWeatherWidget: View {
    @State private var weather = WeatherService()

    var body: some View {
        WidgetCard("Today", tint: Theme.tintToday) {
            VStack(alignment: .leading, spacing: 12) {
                TimelineView(.everyMinute) { context in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())
                            .font(Theme.numeral(54))
                            .foregroundStyle(Theme.text)
                        Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                            .font(Theme.body)
                            .foregroundStyle(Theme.muted)
                    }
                }

                Divider().overlay(Theme.border)

                weatherSection
            }
        }
        .task {
            await weather.refresh()
            // Re-fetch every 20 minutes; conditions don't move faster.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1200))
                await weather.refresh()
            }
        }
    }

    @ViewBuilder
    private var weatherSection: some View {
        if let snap = weather.snapshot {
            HStack(spacing: 10) {
                Image(systemName: snap.symbolName)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(Int(snap.temperature.rounded()))°  \(snap.conditionText)")
                        .font(Theme.bodyMedium)
                        .foregroundStyle(Theme.text)
                    Text("\(snap.place)  ·  H \(Int(snap.todayMax.rounded()))°  L \(Int(snap.todayMin.rounded()))°")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
        } else if let error = weather.error {
            Text(error)
                .font(Theme.caption)
                .foregroundStyle(Theme.faint)
        } else {
            Text("Set a location in Settings for weather.")
                .font(Theme.caption)
                .foregroundStyle(Theme.faint)
        }
    }
}
