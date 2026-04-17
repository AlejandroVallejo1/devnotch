import SwiftUI

/// Color palette and typography helpers.
enum DS {
    // MARK: - Colors
    enum Palette {
        /// Warm near-black used in Claude.ai dark mode.
        static let background    = Color(hex: 0x1A1918)
        /// Slightly lifted surface for cards and sections.
        static let surface       = Color(hex: 0x26231F)
        /// Subtle surface used for chips and inline pills.
        static let surfaceSubtle = Color(hex: 0x2F2B27)
        /// Hairline dividers.
        static let divider       = Color.white.opacity(0.06)

        /// Primary Anthropic coral/orange — signature brand color.
        static let coral         = Color(hex: 0xD97757)
        /// Darker coral for hover / pressed states.
        static let coralDeep     = Color(hex: 0xB8614A)
        /// Muted coral tint for soft backgrounds.
        static let coralSoft     = Color(hex: 0xD97757).opacity(0.18)

        /// Warm cream — primary foreground.
        static let cream         = Color(hex: 0xF5F1E8)
        /// Secondary body text.
        static let warmGray      = Color(hex: 0x8F8B7E)
        /// Tertiary — labels, captions.
        static let warmGrayDim   = Color(hex: 0x5A564F)

        /// Claude.ai progress-bar blue (matches the plan-meter UI).
        static let progressBlue  = Color(hex: 0x4D7EEB)
        /// Muted warm accents, used sparingly for danger/warning.
        static let mustard       = Color(hex: 0xC9A959)
        static let rust          = Color(hex: 0xC96448)
    }

    // MARK: - Semantic helpers

    /// Progress bars stay Claude-blue by default; we only shift to warm tones
    /// when the bar is visually overflowing (≥100%).
    static func usageAccent(for percent: Double) -> Color {
        percent >= 1.0 ? Palette.rust : Palette.progressBlue
    }

    static func usageGradient(for percent: Double) -> LinearGradient {
        let base = usageAccent(for: percent)
        return LinearGradient(colors: [base, base], startPoint: .leading, endPoint: .trailing)
    }

    // MARK: - Fonts
    enum Font {
        static func display(_ size: CGFloat, weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .serif)
        }
        static func number(_ size: CGFloat, weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .rounded)
                .monospacedDigit()
        }
        static func body(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
