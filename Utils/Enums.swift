import Foundation

enum DateRange: String, CaseIterable, Identifiable {
    case m1 = "1M"
    case m3 = "3M"
    case m6 = "6M"
    case y1 = "1Y"
    case y2 = "2Y"
    case y5 = "5Y"
    case all = "All"

    var id: String { rawValue }

    var title: String { rawValue }

    var days: Int? {
        switch self {
        case .m1: return 30
        case .m3: return 90
        case .m6: return 180
        case .y1: return 365
        case .y2: return 730
        case .y5: return 1825
        case .all: return nil
        }
    }
}

enum LoadableState<T: Equatable>: Equatable {
    case idle
    case loading
    case success(T)
    case error(message: String)
}

enum DCAFrequency: String, CaseIterable, Identifiable {
    case monthly = "monthly"
    case weekly = "weekly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monthly: return "Aylık"
        case .weekly: return "Haftalık"
        }
    }
}

enum TradeSource: String {
    case manual
    case dca
}

struct BannerMessage {
    enum Kind {
        case success, warning, error
    }

    let title: String
    let message: String
    let kind: Kind
}

struct ToastMessage: Equatable {
    enum Kind: Equatable {
        case info, success, error
    }

    let message: String
    let kind: Kind
}
