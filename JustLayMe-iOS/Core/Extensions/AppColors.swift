import SwiftUI

// MARK: - App Colors

enum AppColors {
    // MARK: - Primary Colors

    static let primary = Color(hex: "#8B5CF6")
    static let primaryLight = Color(hex: "#A78BFA")
    static let primaryDark = Color(hex: "#7C3AED")

    // MARK: - Background Colors

    static let darkBackground = Color(hex: "#0F0F23")
    static let cardBackground = Color(hex: "#1A1A2E")
    static let inputBackground = Color(hex: "#16213E")

    // MARK: - Text Colors

    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "#A0AEC0")
    static let textMuted = Color(hex: "#718096")

    // MARK: - Accent Colors

    static let success = Color(hex: "#48BB78")
    static let warning = Color(hex: "#ECC94B")
    static let error = Color(hex: "#F56565")
    static let info = Color(hex: "#4299E1")

    // MARK: - Chat Colors

    static let userMessageBackground = Color(hex: "#8B5CF6")
    static let aiMessageBackground = Color(hex: "#2D3748")

    // MARK: - Gradient

    static let primaryGradient = LinearGradient(
        colors: [primary, primaryLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let backgroundGradient = LinearGradient(
        colors: [darkBackground, Color(hex: "#1A1A2E")],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Color Extension

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
}

// MARK: - App Fonts

enum AppFonts {
    static func regular(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    static func medium(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    static func semibold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func bold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    // Preset sizes
    static let title = bold(28)
    static let headline = semibold(20)
    static let body = regular(16)
    static let caption = regular(14)
    static let small = regular(12)
}
