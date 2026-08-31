import SwiftUI

/// Central design tokens. Plain, professional, no decoration for its own sake.
/// Everything adapts to light/dark via dynamic NSColor providers.
enum Theme {

    // MARK: Colors

    /// Window background behind all cards.
    static let background = dynamic(light: NSColor(hex: 0xF2F2F4), dark: NSColor(hex: 0x121215))
    /// Card surface.
    static let card = dynamic(light: NSColor(hex: 0xFFFFFF), dark: NSColor(hex: 0x1C1C21))
    /// Hairline border around cards and separators.
    static let border = dynamic(light: NSColor(hex: 0xE2E2E6), dark: NSColor(hex: 0x2A2A31))
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
