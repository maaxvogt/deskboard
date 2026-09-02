import SwiftUI

struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        TabView {
            claudeTab.tabItem { Label("Claude", systemImage: "terminal") }
            mailTab.tabItem { Label("Mail", systemImage: "envelope") }
            githubTab.tabItem { Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right") }
            inTouchTab.tabItem { Label("inTouch", systemImage: "checklist") }
            spotifyTab.tabItem { Label("Spotify", systemImage: "music.note") }
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
            Text("URL and bearer token of your claude-status-api worker (see README).")
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
            Text("Any IMAP server with TLS on port 993, e.g. imap.example.com. The password is stored in the keychain.")
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
            Text("Backend URL and API key, minted in the inTouch app under Settings → App & Media → inTouch API.")
                .font(Theme.caption)
                .foregroundStyle(Theme.muted)
        }
        .padding(20)
    }

    private var spotifyTab: some View {
        Form {
            TextField("Client ID", text: $settings.spotifyClientID)
            LabeledContent("Redirect URI") {
                Text(SpotifyAuth.redirectURI)
                    .font(Theme.caption.monospaced())
                    .textSelection(.enabled)
            }
            Text("Create an app at developer.spotify.com/dashboard, add the redirect URI above, paste its Client ID here, then connect. Playback controls need Spotify Premium.")
                .font(Theme.caption)
                .foregroundStyle(Theme.muted)

            HStack {
                if spotify.isConnected {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.ok)
                    Spacer()
                    Button("Disconnect") { spotify.disconnect() }
                } else {
                    Label("Not connected", systemImage: "circle")
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Button("Connect Spotify…") { spotify.beginLogin() }
                        .disabled(settings.spotifyClientID.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            if let error = spotify.lastError {
                Text(error)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.bad)
            }
        }
        .padding(20)
    }

    private var spotify: SpotifyAuth { SpotifyAuth.shared }

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
