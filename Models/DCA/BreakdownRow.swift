import Foundation

/// DCA simülasyon sonucunda her varlık için özet bilgileri içeren model
/// Varlığın toplam adedi, ortalama maliyeti, güncel değeri ve kar/zarar bilgilerini içerir
public struct BreakdownRow: Codable, Equatable, Identifiable {
    public let id = UUID()
    public let symbol: String
    public let totalUnits: Decimal
    public let avgCostTRY: Decimal
    public let currentPrice: Decimal
    public let currentValueTRY: Decimal
    public let pnlTRY: Decimal
    public let pnlPct: Decimal
    
    public init(
        symbol: String,
        totalUnits: Decimal,
        avgCostTRY: Decimal,
        currentPrice: Decimal,
        currentValueTRY: Decimal,
        pnlTRY: Decimal,
        pnlPct: Decimal
    ) {
        self.symbol = symbol
        self.totalUnits = totalUnits
        self.avgCostTRY = avgCostTRY
        self.currentPrice = currentPrice
        self.currentValueTRY = currentValueTRY
        self.pnlTRY = pnlTRY
        self.pnlPct = pnlPct
    }
}

// MARK: - Computed Properties
extension BreakdownRow {
    /// Toplam yatırım miktarını döndürür
    public var totalInvestmentTRY: Decimal {
        return totalUnits * avgCostTRY
    }
    
    /// Kar/zarar durumunu döndürür
    public var isProfit: Bool {
        return pnlTRY > 0
    }
    
    /// Zarar durumunu döndürür
    public var isLoss: Bool {
        return pnlTRY < 0
    }
    
    /// Başabaş durumunu döndürür
    public var isBreakEven: Bool {
        return pnlTRY == 0
    }
    
    /// Kar/zarar yüzdesini yüzde formatında döndürür
    public var pnlPctFormatted: String {
        return String(format: "%.2f%%", pnlPct.doubleValue)
    }
    
    /// Kar/zarar miktarını formatlanmış string olarak döndürür
    public var pnlTRYFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "TRY"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: pnlTRY as NSDecimalNumber) ?? "0₺"
    }
    
    /// Güncel değeri formatlanmış string olarak döndürür
    public var currentValueFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "TRY"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: currentValueTRY as NSDecimalNumber) ?? "0₺"
    }
}

// MARK: - Factory Methods
extension BreakdownRow {
    /// Varlık için breakdown row oluşturur
    public static func create(
        symbol: String,
        totalUnits: Decimal,
        avgCostTRY: Decimal,
        currentPrice: Decimal
    ) -> BreakdownRow {
        let currentValueTRY = totalUnits * currentPrice
        let totalInvestmentTRY = totalUnits * avgCostTRY
        let pnlTRY = currentValueTRY - totalInvestmentTRY
        let pnlPct = totalInvestmentTRY > 0 ? (pnlTRY / totalInvestmentTRY) * 100 : 0
        
        return BreakdownRow(
            symbol: symbol,
            totalUnits: totalUnits,
            avgCostTRY: avgCostTRY,
            currentPrice: currentPrice,
            currentValueTRY: currentValueTRY,
            pnlTRY: pnlTRY,
            pnlPct: pnlPct
        )
    }
}

// MARK: - Decimal Extension for doubleValue
private extension Decimal {
}
