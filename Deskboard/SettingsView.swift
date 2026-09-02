import SwiftUI

struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        TabView {
            claudeTab.tabItem { Label("Claude", systemImage: "terminal") }
            mailTab.tabItem { Label("Mail", systemImage: "envelope") }
            githubTab.tabItem { Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right") }
            inTouchTab.tabItem { Label("inTouch", systemImage: "checklist") }
            generalTab.tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 460)
        .padding(.bottom, 4)
        .preferredColorScheme(Theme.colorScheme)
    }

    private var claudeTab: some View {
        Form {
            TextField("API base URL", text: $settings.claudeAPIBase)
            SecureField("API token", text: $settings.claudeToken)
            Text("The bearer token of the claude-status-api worker.")
                .font(Theme.caption)
                .foregroundStyle(Theme.muted)
        }
        .padding(20)
    }

    private var mailTab: some View {
        Form {
            TextField("IMAP host", text: $settings.imapHost)
            TextField("User (email address)", text: $settings.imapUser)
            SecureField("Password", text: $settings.imapPassword)
            Text("IONOS: imap.ionos.de, port 993 (TLS). The password is stored in the keychain.")
                .font(Theme.caption)
                .foregroundStyle(Theme.muted)
        }
        .padding(20)
    }

    private var githubTab: some View {
        Form {
            TextField("Username", text: $settings.githubUser)
            SecureField("Personal access token", text: $settings.githubToken)
            Text("A classic PAT with repo scope, or a fine-grained token with read access.")
                .font(Theme.caption)
                .foregroundStyle(Theme.muted)
        }
        .padding(20)
    }

    private var inTouchTab: some View {
        Form {
            TextField("API base URL", text: $settings.inTouchAPIBase)
            SecureField("API key", text: $settings.inTouchKey)
            Text("Minted in the inTouch app under Settings → App & Media → inTouch API.")
                .font(Theme.caption)
                .foregroundStyle(Theme.muted)
        }
        .padding(20)
    }

    private var windows: WindowManager { WindowManager.shared }

    private var displaySelection: Binding<String> {
        Binding(
            get: { windows.currentScreen?.id ?? "" },
            set: { id in
                if let screen = windows.screens.first(where: { $0.id == id }) { windows.move(to: screen) }
            })
    }

    private var generalTab: some View {
        Form {
            TextField("Weather location (city)", text: $settings.weatherPlace)
            Picker("Appearance", selection: $settings.appearance) {
                ForEach(Appearance.allCases) { Text($0.title).tag($0) }
            }
            Text("Auto follows the system: Light when macOS is light, Dark Color when it is dark.")
                .font(Theme.caption)
                .foregroundStyle(Theme.muted)

            Toggle("Start in full screen", isOn: $settings.startFullScreen)
            Picker("Display", selection: displaySelection) {
                ForEach(windows.screens) { Text($0.localizedName).tag($0.id) }
            }
            Text("Moves the dashboard to that display and keeps it in full screen. Shortcut: ⇧⌘M cycles displays.")
                .font(Theme.caption)
                .foregroundStyle(Theme.muted)
        }
        .padding(20)
    }
}
