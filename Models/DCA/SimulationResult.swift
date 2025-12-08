import Foundation

/// DCA simülasyonunun tam sonucunu temsil eden model
/// Tüm hesaplamaların özetini ve detaylarını içerir
public struct SimulationResult: Codable, Equatable, Identifiable {
    public var id = UUID()
    public let investedTotalTRY: Decimal
    public let currentValueTRY: Decimal
    public let profitTRY: Decimal
    public let profitPct: Decimal
    public let maxDrawdownPct: Decimal
    public let deals: [DealLog]
    public let breakdown: [BreakdownRow]
    public let simulationDate: Date

    public init(
        investedTotalTRY: Decimal,
        currentValueTRY: Decimal,
        profitTRY: Decimal,
        profitPct: Decimal,
        maxDrawdownPct: Decimal = 0,
        deals: [DealLog],
        breakdown: [BreakdownRow],
        simulationDate: Date = Date()
    ) {
        self.investedTotalTRY = investedTotalTRY
        self.currentValueTRY = currentValueTRY
        self.profitTRY = profitTRY
        self.profitPct = profitPct
        self.maxDrawdownPct = maxDrawdownPct
        self.deals = deals
        self.breakdown = breakdown
        self.simulationDate = simulationDate
    }
}

// MARK: - Computed Properties
extension SimulationResult {
    /// Toplam kar/zarar durumunu döndürür
    public var isProfit: Bool {
        return profitTRY > 0
    }

    /// Toplam zarar durumunu döndürür
    public var isLoss: Bool {
        return profitTRY < 0
    }

    /// Başabaş durumunu döndürür
    public var isBreakEven: Bool {
        return profitTRY == 0
    }

    /// Başarılı işlem sayısını döndürür
    public var successfulDealsCount: Int {
        return deals.filter { $0.isSuccessful }.count
    }

    /// Atlanan işlem sayısını döndürür
    public var skippedDealsCount: Int {
        return deals.filter { $0.skipped }.count
    }

    /// Toplam işlem sayısını döndürür
    public var totalDealsCount: Int {
        return deals.count
    }

    /// Başarı oranını döndürür (0.0 - 1.0 arası)
    public var successRate: Decimal {
        guard totalDealsCount > 0 else { return 0 }
        return Decimal(successfulDealsCount) / Decimal(totalDealsCount)
    }

    /// Kar/zarar yüzdesini formatlanmış string olarak döndürür
    public var profitPctFormatted: String {
        return String(format: "%.2f%%", profitPct.doubleValue)
    }

    /// Kar/zarar miktarını formatlanmış string olarak döndürür
    public var profitTRYFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: profitTRY as NSDecimalNumber) ?? "$0"
    }

    /// Yatırılan toplam miktarı formatlanmış string olarak döndürür
    public var investedTotalFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: investedTotalTRY as NSDecimalNumber) ?? "$0"
    }

    /// Güncel değeri formatlanmış string olarak döndürür
    public var currentValueFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: currentValueTRY as NSDecimalNumber) ?? "$0"
    }

    /// Maksimum düşüşü formatlanmış string olarak döndürür
    public var maxDrawdownFormatted: String {
        let value = maxDrawdownPct.doubleValue
        return String(format: "%.2f%%", value)
    }
}

// MARK: - Statistics
extension SimulationResult {
    /// Simülasyon istatistiklerini döndürür
    public var statistics: SimulationStatistics {
        return SimulationStatistics(
            totalDeals: totalDealsCount,
            successfulDeals: successfulDealsCount,
            skippedDeals: skippedDealsCount,
            successRate: successRate,
            totalInvestment: investedTotalTRY,
            currentValue: currentValueTRY,
            profit: profitTRY,
            profitPercentage: profitPct
        )
    }
}

// MARK: - Supporting Types
public struct SimulationStatistics: Codable, Equatable {
    public let totalDeals: Int
    public let successfulDeals: Int
    public let skippedDeals: Int
    public let successRate: Decimal
    public let totalInvestment: Decimal
    public let currentValue: Decimal
    public let profit: Decimal
    public let profitPercentage: Decimal
}

// MARK: - Decimal Extension for doubleValue
extension Decimal {
}
