import Foundation

/// DCA simülasyonundaki her bir işlemi temsil eden model
/// Her ay yapılan alım işlemlerinin detaylarını içerir
public struct DealLog: Codable, Equatable, Identifiable {
    public var id = UUID()
    public let date: Date
    public let targetDate: Date
    public let symbol: String
    public let price: Decimal
    public let units: Decimal
    public let spentTRY: Decimal
    public let skipped: Bool

    public init(
        date: Date,
        targetDate: Date,
        symbol: String,
        price: Decimal,
        units: Decimal,
        spentTRY: Decimal,
        skipped: Bool = false
    ) {
        self.date = date
        self.targetDate = targetDate
        self.symbol = symbol
        self.price = price
        self.units = units
        self.spentTRY = spentTRY
        self.skipped = skipped
    }
}

// MARK: - Computed Properties
extension DealLog {
    /// İşlemin başarılı olup olmadığını döndürür
    public var isSuccessful: Bool {
        return !skipped && units > 0
    }

    /// Hedef tarih ile gerçek tarih arasındaki farkı gün cinsinden döndürür
    public var daysDifference: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: targetDate, to: date)
        return components.day ?? 0
    }

    /// İşlemin açıklamasını döndürür
    public var description: String {
        if skipped {
            return "\(symbol) - Fiyat bulunamadı"
        } else {
            return "\(symbol) - \(units.rounded(scale: 6)) adet @ \(price.rounded(scale: 2))₺"
        }
    }
}

// MARK: - Factory Methods
extension DealLog {
    /// Başarılı işlem oluşturur
    public static func successful(
        date: Date,
        targetDate: Date,
        symbol: String,
        price: Decimal,
        units: Decimal,
        spentTRY: Decimal
    ) -> DealLog {
        return DealLog(
            date: date,
            targetDate: targetDate,
            symbol: symbol,
            price: price,
            units: units,
            spentTRY: spentTRY,
            skipped: false
        )
    }

    /// Atlanan işlem oluşturur
    public static func skipped(
        targetDate: Date,
        symbol: String
    ) -> DealLog {
        return DealLog(
            date: targetDate,
            targetDate: targetDate,
            symbol: symbol,
            price: 0,
            units: 0,
            spentTRY: 0,
            skipped: true
        )
    }
}
