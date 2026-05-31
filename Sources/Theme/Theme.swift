import SwiftUI
import Combine
import AppKit

// MARK: - Theme Mode
enum AppTheme: String {
    case dark
    case light
    case custom
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
            switch theme {
            case .dark: theme = .light
            case .light: theme = .custom
            case .custom: theme = .dark
            }
        }
    }
    
    func forceRefresh() {
        objectWillChange.send()
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
    let playIconColor: Color
    let pauseIconColor: Color
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
                glow:           Color.white.opacity(0.30),
                playIconColor:  Color(white: 0.12),
                pauseIconColor: Color(white: 0.12)
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
                glow:           Color.black.opacity(0.20),
                playIconColor:  .white,
                pauseIconColor: .white
            )

        case .custom:
            let accentHex = UserDefaults.standard.string(forKey: "customAccent") ?? "#FF5500"
            let sidebarHex = UserDefaults.standard.string(forKey: "customSidebar") ?? "#111111"
            let tintHex = UserDefaults.standard.string(forKey: "customAppTint") ?? "#000000"
            let cardHex = UserDefaults.standard.string(forKey: "customCard") ?? "#222222"
            let textHex = UserDefaults.standard.string(forKey: "customTextPrimary") ?? "#FFFFFF"
            let progressHex = UserDefaults.standard.string(forKey: "customProgress") ?? "#FF5500"
            let glowHex = UserDefaults.standard.string(forKey: "customGlow") ?? "#FF5500"
            
            let accent = Color(hex: accentHex)
            let sidebar = Color(hex: sidebarHex)
            let appTint = Color(hex: tintHex)
            let card = Color(hex: cardHex)
            let text = Color(hex: textHex)
            let progress = Color(hex: progressHex)
            let glow = Color(hex: glowHex)
            
            let isAccentLight = isLightColor(hex: accentHex)
            let isTextLight = isLightColor(hex: textHex)
            
            return Palette(
                appTint:        appTint.opacity(0.18),
                sidebar:        sidebar.opacity(0.40),
                card:           card.opacity(0.04),
                cardElevated:   sidebar.opacity(0.45),
                inset:          card.opacity(0.05),
                stroke:         text.opacity(0.09),
                strokeStrong:   text.opacity(0.18),
                divider:        text.opacity(0.07),

                textPrimary:    text,
                textSecondary:  text.opacity(0.72),
                textTertiary:   text.opacity(0.45),

                accent:         accent,
                accentSoft:     accent.opacity(0.10),
                accentSecondary:accent.opacity(0.70),
                accentGradient: [accent, accent.opacity(0.75), accent.opacity(0.5)],
                playGradient: [accent, accent.opacity(0.8)],
                pauseGradient: [text.opacity(0.8), text.opacity(0.5)],
                progressGradient: [progress, progress.opacity(0.7)],

                closeColor:     Color(red: 1.00, green: 0.37, blue: 0.36),
                minimizeColor:  Color(red: 1.00, green: 0.74, blue: 0.18),
                maximizeColor:  Color(red: 0.31, green: 0.84, blue: 0.41),

                cardShadow:     Color.black.opacity(0.55),
                glow:           glow.opacity(0.30),
                playIconColor:  isAccentLight ? Color(white: 0.12) : .white,
                pauseIconColor: isTextLight ? Color(white: 0.12) : .white
            )
        }
    }

    // NSVisualEffectView material (window backing)
    var nsMaterial: NSVisualEffectView.Material {
        switch self {
        case .dark, .custom:  return .hudWindow
        case .light:          return .popover
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .dark, .custom:  return NSAppearance(named: .vibrantDark)
        case .light:          return NSAppearance(named: .vibrantLight)
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

// MARK: - Color Hex Conversion
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String {
        let nsColor = NSColor(self)
        if let rgbColor = nsColor.usingColorSpace(.deviceRGB) {
            let r = Int(max(0, min(255, rgbColor.redComponent * 255)))
            let g = Int(max(0, min(255, rgbColor.greenComponent * 255)))
            let b = Int(max(0, min(255, rgbColor.blueComponent * 255)))
            return String(format: "#%02X%02X%02X", r, g, b)
        }
        return "#FFFFFF"
    }
}

// MARK: - Light/Dark Color Contrast Evaluator
private func isLightColor(hex: String) -> Bool {
    let cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
    var rgb: UInt64 = 0
    Scanner(string: cleanHex).scanHexInt64(&rgb)
    let r = Double((rgb >> 16) & 0xFF) / 255.0
    let g = Double((rgb >> 8) & 0xFF) / 255.0
    let b = Double(rgb & 0xFF) / 255.0
    let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return luminance > 0.6
}
