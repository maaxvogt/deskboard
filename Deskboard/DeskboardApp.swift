import SwiftUI

@main
struct DeskboardApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .frame(minWidth: 880, minHeight: 540)
        }
        // Compact default: fits below the menu bar without touching the Dock;
        // in Sidecar fullscreen it simply scales up.
        .defaultSize(width: 1080, height: 660)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
        }
    }
}
