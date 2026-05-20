import SwiftUI
import Combine
import AppKit

// MARK: - Theme Mode
enum AppTheme: String {
    case dark
    case light
}

// MARK: - Theme Manager
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var theme: AppTheme = .dark {
        didSet {
            NotificationCenter.default.post(name: .themeDidChange, object: theme)
        }
    }

    func toggle() {
        withAnimation(.easeInOut(duration: 0.35)) {
            theme = (theme == .dark) ? .light : .dark
        }
    }
}

extension Notification.Name {
    static let themeDidChange = Notification.Name("ThemeDidChangeNotification")
}

// MARK: - Palette
struct Palette {
    // Backgrounds
    let appTint: Color           // soft tint overlay over NSVisualEffectView
    let sidebar: Color
    let card: Color
    let cardElevated: Color
    let inset: Color             // wells/inputs
    let stroke: Color
    let strokeStrong: Color
    let divider: Color

    // Text
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color

    // Accents
    let accent: Color
    let accentSoft: Color
    let accentSecondary: Color
    let accentGradient: [Color]
    let playGradient: [Color]
    let pauseGradient: [Color]
    let progressGradient: [Color]

    // Window controls
    let closeColor: Color
    let minimizeColor: Color
    let maximizeColor: Color

    // Shadows / glow
    let cardShadow: Color
    let glow: Color
}

extension AppTheme {
    var palette: Palette {
        switch self {
        case .dark:
            // Pure monochrome professional dark — black/white/gray
            return Palette(
                appTint:        Color.black.opacity(0.18),
                sidebar:        Color.black.opacity(0.40),
                card:           Color.white.opacity(0.04),
                cardElevated:   Color.black.opacity(0.45),
                inset:          Color.white.opacity(0.05),
                stroke:         Color.white.opacity(0.09),
                strokeStrong:   Color.white.opacity(0.18),
                divider:        Color.white.opacity(0.07),

                textPrimary:    Color.white,
                textSecondary:  Color(white: 0.72),
                textTertiary:   Color(white: 0.45),

                accent:         Color.white,
                accentSoft:     Color.white.opacity(0.10),
                accentSecondary:Color(white: 0.70),
                accentGradient: [
                    Color.white,
                    Color(white: 0.72),
                    Color(white: 0.42)
                ],
                playGradient: [
                    Color.white,
                    Color(white: 0.78)
                ],
                pauseGradient: [
                    Color(white: 0.86),
                    Color(white: 0.55)
                ],
                progressGradient: [
                    Color.white,
                    Color(white: 0.65)
                ],

                closeColor:     Color(red: 1.00, green: 0.37, blue: 0.36),
                minimizeColor:  Color(red: 1.00, green: 0.74, blue: 0.18),
                maximizeColor:  Color(red: 0.31, green: 0.84, blue: 0.41),

                cardShadow:     Color.black.opacity(0.55),
                glow:           Color.white.opacity(0.30)
            )

        case .light:
            // Pure monochrome professional light — white/black/gray
            return Palette(
                appTint:        Color.white.opacity(0.25),
                sidebar:        Color.white.opacity(0.55),
                card:           Color.black.opacity(0.03),
                cardElevated:   Color.white.opacity(0.78),
                inset:          Color.black.opacity(0.05),
                stroke:         Color.black.opacity(0.08),
                strokeStrong:   Color.black.opacity(0.16),
                divider:        Color.black.opacity(0.07),

                textPrimary:    Color.black,
                textSecondary:  Color(white: 0.32),
                textTertiary:   Color(white: 0.55),

                accent:         Color.black,
                accentSoft:     Color.black.opacity(0.06),
                accentSecondary:Color(white: 0.40),
                accentGradient: [
                    Color.black,
                    Color(white: 0.30),
                    Color(white: 0.55)
                ],
                playGradient: [
                    Color.black,
                    Color(white: 0.25)
                ],
                pauseGradient: [
                    Color(white: 0.20),
                    Color(white: 0.50)
                ],
                progressGradient: [
                    Color.black,
                    Color(white: 0.35)
                ],

                closeColor:     Color(red: 1.00, green: 0.37, blue: 0.36),
                minimizeColor:  Color(red: 1.00, green: 0.74, blue: 0.18),
                maximizeColor:  Color(red: 0.31, green: 0.84, blue: 0.41),

                cardShadow:     Color.black.opacity(0.10),
                glow:           Color.black.opacity(0.20)
            )
        }
    }

    // NSVisualEffectView material (window backing)
    var nsMaterial: NSVisualEffectView.Material {
        switch self {
        case .dark:  return .hudWindow
        case .light: return .popover
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .dark:  return NSAppearance(named: .vibrantDark)
        case .light: return NSAppearance(named: .vibrantLight)
        }
    }
}

// MARK: - Convenience modifiers
struct GlassCard: ViewModifier {
    let palette: Palette
    var corner: CGFloat = 16
    var strong: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(strong ? palette.cardElevated : palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(palette.stroke, lineWidth: 1)
            )
            .shadow(color: palette.cardShadow, radius: 14, x: 0, y: 8)
    }
}

extension View {
    func glassCard(_ palette: Palette, corner: CGFloat = 16, strong: Bool = false) -> some View {
        self.modifier(GlassCard(palette: palette, corner: corner, strong: strong))
    }
}
