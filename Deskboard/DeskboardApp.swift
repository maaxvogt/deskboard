import SwiftUI

@main
struct DeskboardApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .frame(minWidth: 980, minHeight: 640)
        }
        // Default size matches an 11" iPad in Sidecar (~1180×820 pt).
        .defaultSize(width: 1180, height: 800)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
        }
    }
}
