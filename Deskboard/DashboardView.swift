import SwiftUI

/// The dashboard: a fixed four-column layout sized for an iPad used as a
/// second display. Left to right: ambient info, Claude sessions, planning,
/// communication.
struct DashboardView: View {
    var body: some View {
        HStack(spacing: Theme.gridSpacing) {
            VStack(spacing: Theme.gridSpacing) {
                ClockWeatherWidget()
                    .frame(maxHeight: .infinity)
                SystemMonitorWidget()
                    .frame(maxHeight: .infinity)
                DeviceBatteryWidget()
                    .frame(height: 128)
            }

            ClaudeSessionsWidget()

            VStack(spacing: Theme.gridSpacing) {
                CalendarWidget()
                    .frame(maxHeight: .infinity)
                RemindersWidget()
                    .frame(maxHeight: .infinity)
            }

            VStack(spacing: Theme.gridSpacing) {
                EmailWidget()
                    .frame(maxHeight: .infinity)
                GitHubWidget()
                    .frame(maxHeight: .infinity)
            }
        }
        .padding(Theme.gridSpacing)
        .background(Theme.background)
        .background(WindowAccessor())
        .preferredColorScheme(Theme.colorScheme)
    }
}

#Preview {
    DashboardView()
        .frame(width: 1180, height: 800)
}
