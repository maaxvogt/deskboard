import AppKit
import OSLog
import SwiftUI

/// Owns the dashboard's NSWindow: enters full screen on launch (if enabled),
/// moves the window between displays, and exposes the display list for Settings.
@Observable
@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private(set) var window: NSWindow?
    /// Refreshed on attach and whenever displays change.
    private(set) var screens: [NSScreen] = NSScreen.screens

    private let log = Logger(subsystem: "com.maxvogt.deskboard", category: "window")
    private var didAutoEnter = false

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screens = NSScreen.screens }
        }
    }

    /// Called once the dashboard view has a window.
    func attach(_ window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window
        screens = NSScreen.screens
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        log.info("Displays: \(self.screens.map(\.localizedName).joined(separator: ", "), privacy: .public)")

        guard !didAutoEnter else { return }
        didAutoEnter = true
        // Let the window finish restoring its frame first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, let window = self.window else { return }
            if Demo.active {
                // Fixed, windowed size so snapshots are comparable.
                window.setContentSize(NSSize(width: 1200, height: 760))
                window.center()
            } else if let id = AppSettings.shared.lastDisplayID,
               let screen = NSScreen.screens.first(where: { $0.id == id }),
               window.screen?.id != id {
                window.setFrame(self.centered(window.frame.size, on: screen), display: true)
            }
            if AppSettings.shared.startFullScreen, !self.isFullScreen {
                self.log.info("Entering full screen on \(window.screen?.localizedName ?? "?", privacy: .public)")
                window.toggleFullScreen(nil)
            }
        }
    }

    var isFullScreen: Bool { window?.styleMask.contains(.fullScreen) ?? false }

    /// The display the dashboard is currently on.
    var currentScreen: NSScreen? { window?.screen }

    func toggleFullScreen() { window?.toggleFullScreen(nil) }

    /// Moves the dashboard to `screen`, keeping full-screen state. A full-screen
    /// window can't be moved directly, so: leave → move → re-enter.
    func move(to screen: NSScreen) {
        guard let window, window.screen?.id != screen.id else { return }
        log.info("Moving to \(screen.localizedName, privacy: .public)")
        let wasFullScreen = isFullScreen
        Task { @MainActor in
            if wasFullScreen {
                window.toggleFullScreen(nil)
                await waitFor(NSWindow.didExitFullScreenNotification, on: window)
            }
            window.setFrame(centered(window.frame.size, on: screen), display: true)
            if wasFullScreen {
                window.toggleFullScreen(nil)
                await waitFor(NSWindow.didEnterFullScreenNotification, on: window)
            }
            AppSettings.shared.lastDisplayID = window.screen?.id
            log.info("Now on \(window.screen?.localizedName ?? "?", privacy: .public)")
        }
    }

    func moveToNextScreen() {
        let screens = NSScreen.screens
        guard let current = currentScreen,
              let index = screens.firstIndex(where: { $0.id == current.id }), screens.count > 1 else {
            log.error("Cannot move: window on \(self.currentScreen?.localizedName ?? "no screen", privacy: .public), \(screens.count) displays")
            return
        }
        move(to: screens[(index + 1) % screens.count])
    }

    private func centered(_ size: CGSize, on screen: NSScreen) -> NSRect {
        let frame = screen.visibleFrame
        let w = min(size.width, frame.width), h = min(size.height, frame.height)
        return NSRect(x: frame.midX - w / 2, y: frame.midY - h / 2, width: w, height: h)
    }

    private func waitFor(_ name: Notification.Name, on window: NSWindow) async {
        for await _ in NotificationCenter.default.notifications(named: name, object: window) { return }
    }
}

/// Invisible view that hands the hosting NSWindow to `WindowManager`.
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { AccessorView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class AccessorView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { WindowManager.shared.attach(window) }
        }
    }
}

extension NSScreen: @retroactive Identifiable {
    public var id: String {
        let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return number?.stringValue ?? localizedName
    }
}
