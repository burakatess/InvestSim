import Foundation

/// DCA Engine için Decimal extension'ları
/// Hassas finansal hesaplamalar için gerekli utility fonksiyonları
public extension Decimal {
    /// Decimal değerini belirtilen ondalık basamak sayısına yuvarlar
    /// - Parameter scale: Ondalık basamak sayısı
    /// - Returns: Yuvarlanmış Decimal değeri
    func rounded(scale: Int) -> Decimal {
        var result = Decimal()
        var input = self
        
        NSDecimalRound(&result, &input, scale, .bankers)
        return result
    }
    
    /// Decimal değerini belirtilen ondalık basamak sayısına yuvarlar (yukarı)
    /// - Parameter scale: Ondalık basamak sayısı
    /// - Returns: Yukarı yuvarlanmış Decimal değeri
    func roundedUp(scale: Int) -> Decimal {
        var result = Decimal()
        var input = self
        
        NSDecimalRound(&result, &input, scale, .up)
        return result
    }
    
    /// Decimal değerini belirtilen ondalık basamak sayısına yuvarlar (aşağı)
    /// - Parameter scale: Ondalık basamak sayısı
    /// - Returns: Aşağı yuvarlanmış Decimal değeri
    func roundedDown(scale: Int) -> Decimal {
        var result = Decimal()
        var input = self
        
        NSDecimalRound(&result, &input, scale, .down)
        return result
    }
    
    /// Decimal değerinin sıfıra eşit olup olmadığını kontrol eder
    var isZero: Bool {
        return self == 0
    }
    
    /// Decimal değerinin pozitif olup olmadığını kontrol eder
    var isPositive: Bool {
        return self > 0
    }
    
    /// Decimal değerinin negatif olup olmadığını kontrol eder
    var isNegative: Bool {
        return self < 0
    }
    
    /// Decimal değerini Double'a dönüştürür
    var doubleValue: Double {
        return NSDecimalNumber(decimal: self).doubleValue
    }
    
    /// Decimal değerini Int'e dönüştürür (yuvarlanmış)
    var intValue: Int {
        return NSDecimalNumber(decimal: self).intValue
    }
    
    /// İki Decimal değerinin eşit olup olmadığını belirtilen toleransla kontrol eder
    /// - Parameters:
    ///   - other: Karşılaştırılacak diğer Decimal değer
    ///   - tolerance: Tolerans değeri (varsayılan: 0.001)
    /// - Returns: Eşitlik durumu
    func isEqual(to other: Decimal, tolerance: Decimal = 0.001) -> Bool {
        let difference = abs(self - other)
        return difference <= tolerance
    }
    
    /// Decimal değerini yüzde formatında string olarak döndürür
    /// - Parameter scale: Ondalık basamak sayısı (varsayılan: 2)
    /// - Returns: Formatlanmış yüzde string'i
    func percentageString(scale: Int = 2) -> String {
        let rounded = self.rounded(scale: scale)
        return String(format: "%.\(scale)f%%", rounded.doubleValue)
    }
    
    /// Decimal değerini para birimi formatında string olarak döndürür
    /// - Parameters:
    ///   - currencyCode: Para birimi kodu (varsayılan: "TRY")
    ///   - scale: Ondalık basamak sayısı (varsayılan: 2)
    /// - Returns: Formatlanmış para birimi string'i
    func currencyString(currencyCode: String = "TRY", scale: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = scale
        formatter.maximumFractionDigits = scale
        
        return formatter.string(from: self as NSDecimalNumber) ?? "0₺"
    }
}

// MARK: - Mathematical Operations
public extension Decimal {
    /// Güvenli bölme işlemi (sıfıra bölme kontrolü ile)
    /// - Parameter divisor: Bölen
    /// - Returns: Bölüm sonucu veya 0 (bölen sıfır ise)
    func safeDivide(by divisor: Decimal) -> Decimal {
        guard !divisor.isZero else { return 0 }
        return self / divisor
    }
    
    /// Yüzde hesaplama
    /// - Parameter percentage: Yüzde değeri (0-100 arası)
    /// - Returns: Yüzde hesaplanmış değer
    func percentage(of percentage: Decimal) -> Decimal {
        return self * (percentage / 100)
    }
    
    /// Yüzde artış hesaplama
    /// - Parameter percentage: Artış yüzdesi
    /// - Returns: Artış sonrası değer
    func increased(by percentage: Decimal) -> Decimal {
        return self * (1 + percentage / 100)
    }
    
    /// Yüzde azalış hesaplama
    /// - Parameter percentage: Azalış yüzdesi
    /// - Returns: Azalış sonrası değer
    func decreased(by percentage: Decimal) -> Decimal {
        return self * (1 - percentage / 100)
    }
}
