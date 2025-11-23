import SwiftUI

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var themePreference: ThemePreference {
        didSet {
            UserDefaults.standard.set(themePreference.rawValue, forKey: "themePreference")
        }
    }

    var colorScheme: ColorScheme? {
        switch themePreference {
        case .light: return .light
        case .dark: return .dark
        case .auto: return nil
        }
    }

    private init() {
        let savedTheme = UserDefaults.standard.string(forKey: "themePreference") ?? "auto"
        self.themePreference = ThemePreference(rawValue: savedTheme) ?? .auto
    }
}

enum ThemePreference: String, CaseIterable {
    case auto
    case light
    case dark

    var displayName: String {
        switch self {
        case .auto: return "Auto (System)"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

// MARK: - App Colors

extension Color {
    static let appPrimary = Color(hex: "#6b46ff")
    static let appSecondary = Color(hex: "#ff4690")
    static let appGold = Color(hex: "#ffd700")
    static let appSuccess = Color(hex: "#4ade80")
    static let appDarkBg = Color(hex: "#0a0a0a")
    static let appCardBg = Color(hex: "#1a1a1f")
    static let appTextPrimary = Color.white
    static let appTextSecondary = Color(hex: "#a0a0b0")
    static let appBorder = Color.white.opacity(0.1)

    static let premiumGradient = LinearGradient(
        colors: [.appPrimary, .appSecondary],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let goldGradient = LinearGradient(
        colors: [Color(hex: "#ffd700"), Color(hex: "#ffed4e")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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
}
