import SwiftUI

public extension Color {
    // MARK: - Modern Financial App Color System
    
    // Primary Colors - Trust & Stability
    static let primaryBlue = Color(hex: "#2D81F7") // Primary blue
    static let primaryBlueDark = Color(hex: "#1E5BB8") // Darker blue
    static let primaryBlueLight = Color(hex: "#5BA0F9") // Lighter blue
    
    // Secondary Colors - Vitality & Action
    static let secondaryTeal = Color(hex: "#14B8A6") // Turquoise
    static let secondaryTealDark = Color(hex: "#0F9B8A") // Darker teal
    static let secondaryTealLight = Color(hex: "#3CC5B5") // Lighter teal
    
    // Financial Status Colors
    static let success = Color(hex: "#22C55E") // Positive (gain)
    static let successLight = Color(hex: "#4ADE80") // Light success
    static let successDark = Color(hex: "#16A34A") // Dark success
    
    static let error = Color(hex: "#EF4444") // Negative (loss)
    static let errorLight = Color(hex: "#F87171") // Light error
    static let errorDark = Color(hex: "#DC2626") // Dark error
    
    static let warning = Color(hex: "#F59E0B") // Warning
    static let warningLight = Color(hex: "#FBBF24") // Light warning
    static let warningDark = Color(hex: "#D97706") // Dark warning
    
    // Neutral Colors - Clean & Professional
    static let backgroundPrimary = Color(hex: "#F3F4F6") // Light background
    static let backgroundSecondary = Color.white
    static let backgroundTertiary = Color(hex: "#F9FAFB") // Very light background
    
    static let textPrimary = Color(hex: "#111827") // Dark text
    static let textSecondary = Color(hex: "#6B7280") // Medium text
    static let textTertiary = Color(hex: "#9CA3AF") // Light text
    static let textQuaternary = Color(hex: "#D1D5DB") // Very light text
    
    // Border Colors
    static let borderLight = Color(hex: "#E5E7EB") // Light border
    static let borderMedium = Color(hex: "#D1D5DB") // Medium border
    static let borderDark = Color(hex: "#9CA3AF") // Dark border
    
    // Chart Colors - Vibrant & Distinct
    static let chartBlue = Color(hex: "#2D81F7")
    static let chartGreen = Color(hex: "#22C55E")
    static let chartRed = Color(hex: "#EF4444")
    static let chartOrange = Color(hex: "#F59E0B")
    static let chartPurple = Color(hex: "#8B5CF6")
    static let chartTeal = Color(hex: "#14B8A6")
    static let chartPink = Color(hex: "#EC4899")
    static let chartYellow = Color(hex: "#EAB308")
    
    // Gradient Colors
    static let gradientBlue = LinearGradient(
        colors: [Color(hex: "#EFF6FF"), Color(hex: "#DBEAFE")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let gradientGreen = LinearGradient(
        colors: [Color(hex: "#F0FDF4"), Color(hex: "#DCFCE7")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let gradientRed = LinearGradient(
        colors: [Color(hex: "#FEF2F2"), Color(hex: "#FEE2E2")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let gradientTeal = LinearGradient(
        colors: [Color(hex: "#F0FDFA"), Color(hex: "#CCFBF1")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// Note: Color hex initializer is already defined in DashboardView.swift

// Dark Mode Support
extension Color {
    static let adaptiveBackground = Color(UIColor.systemBackground)
    static let adaptiveSecondaryBackground = Color(UIColor.secondarySystemBackground)
    static let adaptiveTertiaryBackground = Color(UIColor.tertiarySystemBackground)
    
    static let adaptiveLabel = Color(UIColor.label)
    static let adaptiveSecondaryLabel = Color(UIColor.secondaryLabel)
    static let adaptiveTertiaryLabel = Color(UIColor.tertiaryLabel)
    
    static let adaptiveSeparator = Color(UIColor.separator)
    static let adaptiveOpaqueSeparator = Color(UIColor.opaqueSeparator)
}

// MARK: - Single global hex initializer for Color
public extension Color {
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
