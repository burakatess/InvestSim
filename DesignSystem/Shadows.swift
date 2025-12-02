import SwiftUI

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    
    static let none = ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
    static let small = ShadowStyle(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    static let medium = ShadowStyle(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    static let large = ShadowStyle(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    static let xlarge = ShadowStyle(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
}

struct ShadowModifier: ViewModifier {
    let shadow: ShadowStyle
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: shadow.color,
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
    }
}

extension View {
    func shadow(_ style: ShadowStyle) -> some View {
        modifier(ShadowModifier(shadow: style))
    }
    
    // Convenience methods
    func shadowSmall() -> some View {
        shadow(.small)
    }
    
    func shadowMedium() -> some View {
        shadow(.medium)
    }
    
    func shadowLarge() -> some View {
        shadow(.large)
    }
    
    func shadowXLarge() -> some View {
        shadow(.xlarge)
    }
}
