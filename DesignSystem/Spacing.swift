import SwiftUI

struct Spacing {
    // Base spacing unit (8 points)
    static let xs: CGFloat = 4    // 0.5x
    static let sm: CGFloat = 8    // 1x
    static let md: CGFloat = 16   // 2x
    static let lg: CGFloat = 24   // 3x
    static let xl: CGFloat = 32   // 4x
    static let xxl: CGFloat = 48  // 6x
    static let xxxl: CGFloat = 64 // 8x
    
    // Semantic spacing
    static let padding: CGFloat = 16
    static let margin: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let cardSpacing: CGFloat = 12
    static let itemSpacing: CGFloat = 8
}

// Spacing View Modifiers
extension View {
    // Convenience methods
    func paddingXS(_ edges: Edge.Set = .all) -> some View {
        padding(edges, Spacing.xs)
    }
    
    func paddingSM(_ edges: Edge.Set = .all) -> some View {
        padding(edges, Spacing.sm)
    }
    
    func paddingMD(_ edges: Edge.Set = .all) -> some View {
        padding(edges, Spacing.md)
    }
    
    func paddingLG(_ edges: Edge.Set = .all) -> some View {
        padding(edges, Spacing.lg)
    }
    
    func paddingXL(_ edges: Edge.Set = .all) -> some View {
        padding(edges, Spacing.xl)
    }
}
