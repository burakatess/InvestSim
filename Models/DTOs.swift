import Foundation

// MARK: - Portfolio Summary DTOs
struct PortfolioSummary: Codable {
    let totalValue: Decimal
    let totalCost: Decimal
    let profitLoss: Decimal
    let profitLossPercentage: Decimal
    let assetCount: Int
    let lastUpdated: Date
}

struct AssetSummary: Codable, Identifiable, Equatable {
    var id = UUID()
    let asset: AssetCode
    let quantity: Decimal
    let averageCost: Decimal
    let currentPrice: Decimal
    let currentValue: Decimal
    let profitLoss: Decimal
    let profitLossPercentage: Decimal
    let allocation: Decimal
    let roi: Decimal
    let totalCost: Decimal
    let totalUnits: Decimal
    let avgCost: Decimal
    let pnl: Decimal
}

struct AssetSnapshotDTO: Codable, Identifiable, Equatable {
    var id = UUID()
    let asset: AssetCode
    let units: Decimal
    let avgCost: Decimal
    let currentPrice: Decimal
    let currentValue: Decimal
    let pnl: Decimal
    let roi: Decimal
}

struct PricePointDTO: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let value: Decimal
}

struct AllocationSlice: Codable, Identifiable, Equatable {
    let id: String
    let asset: AssetCode
    let value: Decimal
    let percentage: Double
    let color: String
}

struct PriceSeries: Codable, Equatable {
    let points: [PricePoint]
}

struct DashboardData: Codable, Equatable {
    let summary: AssetSummary
    let allocation: [AllocationSlice]
    let timeseries: PriceSeries
    let assets: [AssetSnapshotDTO]
    var recentActivity: [ActivityItem]
}

struct ActivityItem: Codable, Identifiable, Equatable {
    let id: UUID
    let type: ActivityType
    let title: String
    let subtitle: String
    let value: String
    let date: Date

    init(type: ActivityType, title: String, subtitle: String, value: String, date: Date) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.date = date
    }
}

enum ActivityType: String, Codable, CaseIterable {
    case buy = "buy"
    case sell = "sell"
    case dividend = "dividend"
    case transfer = "transfer"
}

struct TradeSummary: Codable, Identifiable {
    var id = UUID()
    let asset: String
    let quantity: Decimal
    let unitPrice: Decimal
    let totalCost: Decimal
    let tradeDate: Date
    let tradeType: String
}

// MARK: - DCA Plan DTOs
struct DCAPlanSummary: Codable, Identifiable {
    var id = UUID()
    let asset: String
    let frequency: String
    let amount: Decimal
    let dayOfMonth: Int
    let dayOfWeek: Int
    let isActive: Bool
    let nextExecution: Date?
    let totalInvested: Decimal
    let totalValue: Decimal
    let profitLoss: Decimal
    let profitLossPercentage: Decimal
}

// MARK: - Scenario DTOs
struct ScenarioSummary: Codable, Identifiable {
    var id = UUID()
    let name: String
    let description: String
    let startDate: Date
    let endDate: Date
    let initialAmount: Decimal
    let monthlyContribution: Decimal
    let isActive: Bool
    let totalValue: Decimal
    let totalCost: Decimal
    let profitLoss: Decimal
    let profitLossPercentage: Decimal
    let lastSnapshot: Date?
}

struct ScenarioSnapshotSummary: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let totalValue: Decimal
    let totalCost: Decimal
    let profitLoss: Decimal
    let profitLossPercentage: Decimal
}

// MARK: - Price Data DTOs
struct PriceData: Codable {
    let asset: String
    let currency: String
    let prices: [PricePoint]
    let lastUpdated: Date
}

public struct PriceHistoryDTO: Codable, Identifiable {
    public var id = UUID()
    public let date: Date
    public let price: Decimal

    public init(date: Date, price: Decimal) {
        self.date = date
        self.price = price
    }
}

struct PriceResponse: Codable {
    let success: Bool
    let data: PriceData?
    let error: String?
}

// MARK: - API Response DTOs
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: String?
    let timestamp: Date
}

// MARK: - Error DTOs
struct APIError: Codable, Error {
    let code: Int
    let message: String
    let details: String?
}
