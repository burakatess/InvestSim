import Combine
import Foundation
import SwiftUI

struct Portfolio: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    var isDefault: Bool
    var color: PortfolioColor

    init(
        id: UUID = UUID(), name: String, createdAt: Date = Date(), isDefault: Bool = false,
        color: PortfolioColor = .blue
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isDefault = isDefault
        self.color = color
    }
}

enum PortfolioColor: String, CaseIterable, Codable {
    case blue = "blue"
    case green = "green"
    case purple = "purple"
    case orange = "orange"
    case red = "red"
    case pink = "pink"
    case teal = "teal"
    case indigo = "indigo"

    var color: Color {
        switch self {
        case .blue: return Color(hex: "#2563EB")
        case .green: return Color(hex: "#16A34A")
        case .purple: return Color(hex: "#7C3AED")
        case .orange: return Color(hex: "#F97316")
        case .red: return Color(hex: "#DC2626")
        case .pink: return Color(hex: "#EC4899")
        case .teal: return Color(hex: "#14B8A6")
        case .indigo: return Color(hex: "#4338CA")
        }
    }

    var icon: String {
        switch self {
        case .blue: return "circle.fill"
        case .green: return "leaf.fill"
        case .purple: return "star.fill"
        case .orange: return "sun.max.fill"
        case .red: return "heart.fill"
        case .pink: return "sparkles"
        case .teal: return "drop.fill"
        case .indigo: return "moon.fill"
        }
    }

    var localizedName: String {
        switch self {
        case .blue: return "Ocean Blue"
        case .green: return "Forest Green"
        case .purple: return "Default Purple"
        case .orange: return "Sunset Orange"
        case .red: return "Fire Red"
        case .pink: return "Cotton Pink"
        case .teal: return "Ice Mint"
        case .indigo: return "Deep Space"
        }
    }
}
