import SwiftUI

/// The user-selectable appearance. `auto` follows the system: light → `.light`,
/// dark → `.darkColor` (the tinted look).
enum Appearance: String, CaseIterable, Identifiable {
    case auto, light, dark, darkColor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        case .darkColor: "Dark Color"
        }
    }
}

/// Central design tokens. Plain, professional, no decoration for its own sake.
///
/// Three palettes:
/// - **light**: soft-UI. One uniform grey surface; cards are pressed *into* the
///   background with inner shadows, content stays flat.
/// - **dark**: the same soft-UI in dark grey. Cards share the ground colour and are
///   pressed in with inner shadows; no borders.
/// - **darkColor**: the tinted look — every widget on its own quietly coloured surface.
///
/// Tokens are computed so they follow `AppSettings.shared.appearance`; SwiftUI
/// tracks that access and re-renders on change. In `auto` the colours are
/// dynamic NSColors that resolve per window appearance.
enum Theme {

    enum Mode { case light, dark, darkColor }

    /// The pinned mode, or nil when following the system.
    static var fixedMode: Mode? {
        switch AppSettings.shared.appearance {
        case .auto: nil
        case .light: .light
        case .dark: .dark
        case .darkColor: .darkColor
        }
    }

    /// Color scheme to force on windows (nil = system).
    static var colorScheme: ColorScheme? {
        switch fixedMode {
        case .light: .light
        case .dark, .darkColor: .dark
        case nil: nil
        }
    }

    /// Resolves the effective mode given the window's color scheme.
    static func mode(for scheme: ColorScheme) -> Mode {
        fixedMode ?? (scheme == .dark ? .darkColor : .light)
    }

    // MARK: Colors

    /// Window background behind all cards.
    static var background: Color { color(light: 0xDDE1E7, dark: 0x1C1C20, darkColor: 0x101013) }
    /// Neutral card surface. In light and dark this equals the background — the
    /// inner shadow alone separates card from ground.
    static var card: Color { color(light: 0xDDE1E7, dark: 0x1C1C20, darkColor: 0x1C1C21) }
    /// Hairline for separators inside cards.
    static var border: Color { color(light: 0xC6CAD3, dark: 0x2C2C32, darkColor: 0x2A2A31) }
    /// Primary text.
    static var text: Color { color(light: 0x3A3A44, dark: 0xE8E8EC, darkColor: 0xEBEBEF) }
    /// Secondary / muted text.
    static var muted: Color { color(light: 0x6E6E78, dark: 0x8E8E98, darkColor: 0x94949E) }
    /// Faint text (timestamps, tertiary info).
    static var faint: Color { color(light: 0x9A9AA6, dark: 0x5E5E68, darkColor: 0x64646E) }
    /// Subtle accent — steel blue, used sparingly.
    static var accent: Color { color(light: 0x3D6BB3, dark: 0x8FA8C8, darkColor: 0x6E97D4) }
    /// Subtle fill for rows/badges/bar tracks.
    static var fill: Color { color(light: 0xD1D5DD, dark: 0x27272C, darkColor: 0x26262C) }

    // Status colors (muted, not neon)
    static var ok: Color { color(light: 0x2E7D4F, dark: 0x5DB884, darkColor: 0x5DB884) }
    static var warn: Color { color(light: 0xB07A1E, dark: 0xD9A84E, darkColor: 0xD9A84E) }
    static var bad: Color { color(light: 0xB3402E, dark: 0xD4705F, darkColor: 0xD4705F) }
    static var info: Color { color(light: 0x3D6BB3, dark: 0x8FA8C8, darkColor: 0x6E97D4) }

    // MARK: Soft-UI shadows (pressed cards in light and dark)

    /// Dark edge of a pressed surface (top-left inside).
    static func insetShade(for mode: Mode) -> Color {
        mode == .light ? Color(nsColor: NSColor(hex: 0xB8BCC8)) : Color.black.opacity(0.75)
    }
    /// Light edge of a pressed surface (bottom-right inside).
    static func insetLight(for mode: Mode) -> Color {
        mode == .light ? Color.white.opacity(0.75) : Color.white.opacity(0.09)
    }

    // MARK: Widget tints
    // In darkColor each widget gets its own quietly tinted surface (instead of
    // borders) and a matching accent for its title. In light and dark the
    // surface is the neutral card; only the accent survives.

    struct Tint {
        let surface: Color
        let accent: Color
    }

    static var tintToday: Tint { tint(surface: 0x1C2634, light: 0x3D6BB3, dark: 0x82A8DE) }
    static var tintSystem: Tint { tint(surface: 0x172725, light: 0x2E7D74, dark: 0x6FBDB2) }
    static var tintBattery: Tint { tint(surface: 0x1B2A1C, light: 0x2E7D4F, dark: 0x6FBE8E) }
    static var tintClaude: Tint { tint(surface: 0x232136, light: 0x5B54B0, dark: 0x9D96DF) }
    static var tintCalendar: Tint { tint(surface: 0x2D2022, light: 0xB04A44, dark: 0xD98A82) }
    static var tintSpotify: Tint { tint(surface: 0x182A21, light: 0x1E8C55, dark: 0x62C98D) }
    static var tintReminders: Tint { tint(surface: 0x2B2518, light: 0xA87A1C, dark: 0xD3A94E) }
    static var tintMail: Tint { tint(surface: 0x1A2733, light: 0x3577A8, dark: 0x7FB2D9) }
    static var tintGitHub: Tint { tint(surface: 0x25242C, light: 0x63637A, dark: 0xA2A2B5) }
    static var tintNeutral: Tint { Tint(surface: card, accent: muted) }

    private static func tint(surface darkColorSurface: UInt32, light: UInt32, dark: UInt32) -> Tint {
        Tint(
            surface: color(light: 0xDDE1E7, dark: 0x1C1C20, darkColor: darkColorSurface),
            accent: color(light: light, dark: dark, darkColor: dark))
    }

    // MARK: Typography

    /// Card section title.
    static let widgetTitle = Font.system(size: 11, weight: .semibold).lowercaseSmallCaps()
    /// Standard row text.
    static let body = Font.system(size: 13)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    /// Secondary row text.
    static let caption = Font.system(size: 11)
    /// Large numerals (clock, stats).
    static func numeral(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        Font.system(size: size, weight: weight).monospacedDigit()
    }

    // MARK: Metrics

    static let cardRadius: CGFloat = 10
    static let cardPadding: CGFloat = 14
    static let gridSpacing: CGFloat = 12

    // MARK: Resolution

    private static func color(light: UInt32, dark: UInt32, darkColor: UInt32) -> Color {
        switch fixedMode {
        case .light: Color(nsColor: NSColor(hex: light))
        case .dark: Color(nsColor: NSColor(hex: dark))
        case .darkColor: Color(nsColor: NSColor(hex: darkColor))
        case nil: dynamic(light: NSColor(hex: light), dark: NSColor(hex: darkColor))
        }
    }

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
