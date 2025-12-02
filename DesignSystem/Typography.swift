import SwiftUI

extension Font {
    // MARK: - Modern Financial App Typography System
    
    // Display Fonts - Large Numbers & Values
    static let displayLarge = Font.system(size: 48, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 36, weight: .bold, design: .rounded)
    static let displaySmall = Font.system(size: 28, weight: .bold, design: .rounded)
    
    // Headline Fonts - Section Titles
    static let headlineLarge = Font.system(size: 28, weight: .bold, design: .default)
    static let headlineMedium = Font.system(size: 24, weight: .bold, design: .default)
    static let headlineSmall = Font.system(size: 20, weight: .bold, design: .default)
    
    // Title Fonts - Card Titles & Important Text
    static let titleLarge = Font.system(size: 18, weight: .semibold, design: .default)
    static let titleMedium = Font.system(size: 16, weight: .semibold, design: .default)
    static let titleSmall = Font.system(size: 14, weight: .semibold, design: .default)
    
    // Body Fonts - Regular Text
    static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 14, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 12, weight: .regular, design: .default)
    
    // Label Fonts - UI Labels & Captions
    static let labelLarge = Font.system(size: 14, weight: .medium, design: .default)
    static let labelMedium = Font.system(size: 12, weight: .medium, design: .default)
    static let labelSmall = Font.system(size: 10, weight: .medium, design: .default)
    
    // Financial Fonts - Money & Numbers (Monospaced for alignment)
    static let moneyLarge = Font.system(size: 32, weight: .bold, design: .monospaced)
    static let moneyMedium = Font.system(size: 24, weight: .bold, design: .monospaced)
    static let moneySmall = Font.system(size: 18, weight: .semibold, design: .monospaced)
    static let moneyTiny = Font.system(size: 14, weight: .medium, design: .monospaced)
    
    // Percentage Fonts - Performance Indicators
    static let percentageLarge = Font.system(size: 20, weight: .bold, design: .monospaced)
    static let percentageMedium = Font.system(size: 16, weight: .semibold, design: .monospaced)
    static let percentageSmall = Font.system(size: 12, weight: .medium, design: .monospaced)
    
    // Button Fonts - Action Buttons
    static let buttonLarge = Font.system(size: 16, weight: .semibold, design: .default)
    static let buttonMedium = Font.system(size: 14, weight: .semibold, design: .default)
    static let buttonSmall = Font.system(size: 12, weight: .semibold, design: .default)
    
    // Tab Fonts - Navigation
    static let tabActive = Font.system(size: 12, weight: .semibold, design: .default)
    static let tabInactive = Font.system(size: 12, weight: .medium, design: .default)
}

// Text Style Modifiers
struct TextStyleModifier: ViewModifier {
    let color: Color
    let alignment: TextAlignment
    
    init(color: Color = .adaptiveLabel, alignment: TextAlignment = .leading) {
        self.color = color
        self.alignment = alignment
    }
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(color)
            .multilineTextAlignment(alignment)
    }
}

extension View {
    func textStyle(_ color: Color = .adaptiveLabel, alignment: TextAlignment = .leading) -> some View {
        modifier(TextStyleModifier(color: color, alignment: alignment))
    }
}
