import Combine
import Foundation

/// DCA Engine için fiyat sağlayıcı protokolü
/// Tarihsel ve güncel fiyat verilerini sağlar
public protocol DCAProvider {
    /// Belirtilen tarihte varlığın fiyatını döndürür
    /// - Parameters:
    ///   - date: Tarih
    ///   - symbol: Varlık sembolü
    /// - Returns: Fiyat (bulunamazsa nil)
    func historicalPrice(on date: Date, symbol: String) -> Decimal?

    /// Varlığın güncel fiyatını döndürür
    /// - Parameter symbol: Varlık sembolü
    /// - Returns: Güncel fiyat (bulunamazsa nil)
    func latestPrice(symbol: String) -> Decimal?

    /// Belirtilen tarih aralığında varlığın fiyatlarını döndürür
    /// - Parameters:
    ///   - symbol: Varlık sembolü
    ///   - startDate: Başlangıç tarihi
    ///   - endDate: Bitiş tarihi
    /// - Returns: Tarih-fiyat çiftleri
    func priceHistory(symbol: String, from startDate: Date, to endDate: Date) -> [Date: Decimal]

    /// Varlığın mevcut olup olmadığını kontrol eder
    /// - Parameter symbol: Varlık sembolü
    /// - Returns: Varlık mevcut mu?
    func isSymbolAvailable(_ symbol: String) -> Bool

    /// Mevcut tüm varlık sembollerini döndürür
    /// - Returns: Varlık sembolleri listesi
    func availableSymbols() -> [String]
}

// MARK: - Default Implementation
extension DCAProvider {
    /// Belirtilen tarih aralığında varlığın fiyatlarını döndürür
    public func priceHistory(symbol: String, from startDate: Date, to endDate: Date) -> [Date:
        Decimal]
    {
        var prices: [Date: Decimal] = [:]
        let calendar = Calendar.current
        var currentDate = startDate

        while currentDate <= endDate {
            if let price = historicalPrice(on: currentDate, symbol: symbol) {
                prices[currentDate] = price
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return prices
    }

    /// Varlığın mevcut olup olmadığını kontrol eder
    public func isSymbolAvailable(_ symbol: String) -> Bool {
        return latestPrice(symbol: symbol) != nil
    }

    /// Mevcut tüm varlık sembollerini döndürür
    public func availableSymbols() -> [String] {
        // Default implementation - override in concrete classes
        return []
    }
}
