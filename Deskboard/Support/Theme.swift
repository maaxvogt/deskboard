import SwiftUI

/// Central design tokens. Plain, professional, no decoration for its own sake.
/// Everything adapts to light/dark via dynamic NSColor providers.
enum Theme {

    // MARK: Colors

    /// Window background behind all cards.
    static let background = dynamic(light: NSColor(hex: 0xEBECEF), dark: NSColor(hex: 0x101013))
    /// Neutral card surface (fallback when a widget has no tint).
    static let card = dynamic(light: NSColor(hex: 0xFFFFFF), dark: NSColor(hex: 0x1C1C21))
    /// Hairline for separators inside cards.
    static let border = dynamic(light: NSColor(hex: 0xDDDDE2), dark: NSColor(hex: 0x2A2A31))
    /// Primary text.
    static let text = dynamic(light: NSColor(hex: 0x1B1B1F), dark: NSColor(hex: 0xEBEBEF))
    /// Secondary / muted text.
    static let muted = dynamic(light: NSColor(hex: 0x70707A), dark: NSColor(hex: 0x94949E))
    /// Faint text (timestamps, tertiary info).
    static let faint = dynamic(light: NSColor(hex: 0xA0A0AA), dark: NSColor(hex: 0x64646E))
    /// Subtle accent — steel blue, used sparingly.
    static let accent = dynamic(light: NSColor(hex: 0x3D6BB3), dark: NSColor(hex: 0x6E97D4))
    /// Subtle fill for rows/badges.
    static let fill = dynamic(light: NSColor(hex: 0xF4F4F6), dark: NSColor(hex: 0x26262C))

    // Status colors (muted, not neon)
    static let ok = dynamic(light: NSColor(hex: 0x2E7D4F), dark: NSColor(hex: 0x5DB884))
    static let warn = dynamic(light: NSColor(hex: 0xB07A1E), dark: NSColor(hex: 0xD9A84E))
    static let bad = dynamic(light: NSColor(hex: 0xB3402E), dark: NSColor(hex: 0xD4705F))
    static let info = dynamic(light: NSColor(hex: 0x3D6BB3), dark: NSColor(hex: 0x6E97D4))

    // MARK: Widget tints
    // Each widget gets its own quietly tinted surface (instead of borders) and
    // a matching accent for its title. Muted hues — color, not carnival.

    struct Tint {
        let surface: Color
        let accent: Color
    }

    static let tintToday = Tint(
        surface: dynamic(light: NSColor(hex: 0xE7EEF8), dark: NSColor(hex: 0x1C2634)),
        accent: dynamic(light: NSColor(hex: 0x3D6BB3), dark: NSColor(hex: 0x82A8DE)))
    static let tintSystem = Tint(
        surface: dynamic(light: NSColor(hex: 0xE3F0ED), dark: NSColor(hex: 0x172725)),
        accent: dynamic(light: NSColor(hex: 0x2E7D74), dark: NSColor(hex: 0x6FBDB2)))
    static let tintBattery = Tint(
        surface: dynamic(light: NSColor(hex: 0xE7F2E7), dark: NSColor(hex: 0x1B2A1C)),
        accent: dynamic(light: NSColor(hex: 0x2E7D4F), dark: NSColor(hex: 0x6FBE8E)))
    static let tintClaude = Tint(
        surface: dynamic(light: NSColor(hex: 0xECEAF8), dark: NSColor(hex: 0x232136)),
        accent: dynamic(light: NSColor(hex: 0x5B54B0), dark: NSColor(hex: 0x9D96DF)))
    static let tintCalendar = Tint(
        surface: dynamic(light: NSColor(hex: 0xF8ECEB), dark: NSColor(hex: 0x2D2022)),
        accent: dynamic(light: NSColor(hex: 0xB04A44), dark: NSColor(hex: 0xD98A82)))
    static let tintReminders = Tint(
        surface: dynamic(light: NSColor(hex: 0xF7F0E0), dark: NSColor(hex: 0x2B2518)),
        accent: dynamic(light: NSColor(hex: 0xA87A1C), dark: NSColor(hex: 0xD3A94E)))
    static let tintMail = Tint(
        surface: dynamic(light: NSColor(hex: 0xE4F0F7), dark: NSColor(hex: 0x1A2733)),
        accent: dynamic(light: NSColor(hex: 0x3577A8), dark: NSColor(hex: 0x7FB2D9)))
    static let tintGitHub = Tint(
        surface: dynamic(light: NSColor(hex: 0xEEEDF3), dark: NSColor(hex: 0x25242C)),
        accent: dynamic(light: NSColor(hex: 0x63637A), dark: NSColor(hex: 0xA2A2B5)))
    static let tintNeutral = Tint(surface: card, accent: muted)

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
