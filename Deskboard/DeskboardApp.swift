import SwiftUI

@main
struct DeskboardApp: App {
    init() {
        #if DEBUG
        DebugSnapshot.scheduleIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .frame(minWidth: 880, minHeight: 540)
        }
        // Compact default: fits below the menu bar without touching the Dock;
        // in Sidecar fullscreen it simply scales up.
        .defaultSize(width: 1080, height: 660)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Move to Next Display") { WindowManager.shared.moveToNextScreen() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
        }
    }
}

#if DEBUG
/// Verification aid: `Deskboard --snapshot=/path/out.png` renders the dashboard
/// window to a PNG after the widgets had time to load, then quits. Works without
/// screen-recording permission because it draws the view hierarchy itself.
/// Add `--move-next` to move the window to the next display first (the PNG then
/// has that display's size when in full screen). Combine with `--demo` and
/// `--appearance=…` (see `Demo`) for screenshots with sample data.
enum DebugSnapshot {
    static func scheduleIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let arg = args.first(where: { $0.hasPrefix("--snapshot=") }) else { return }
        let path = String(arg.dropFirst("--snapshot=".count))
        if args.contains("--move-next") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { WindowManager.shared.moveToNextScreen() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            defer { NSApp.terminate(nil) }
            guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }),
                  let view = window.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
    }
}
#endif
