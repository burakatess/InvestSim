import Foundation

/// DCA Engine'de oluşabilecek hata tiplerini tanımlar
public enum DCAError: Error, LocalizedError, Equatable {
    case invalidWeightsSum(actual: Decimal, expected: Decimal)
    case monthsOutOfRange(actual: Int, min: Int, max: Int)
    case buyDayOutOfRange(actual: Int, min: Int, max: Int)
    case emptyAllocations
    case invalidAllocation(symbol: String, weight: Decimal)
    case priceNotFound(symbol: String, date: Date)
    case noPriceDataAvailable(symbol: String)
    case simulationFailed(reason: String)
    case invalidConfiguration(String)
    case noInvestmentDates
    
    public var errorDescription: String? {
        switch self {
        case .invalidWeightsSum(let actual, let expected):
            return "Ağırlık toplamı geçersiz. Beklenen: \(expected), Bulunan: \(actual)"
            
        case .monthsOutOfRange(let actual, let min, let max):
            return "Ay sayısı geçersiz. Geçerli aralık: \(min)-\(max), Bulunan: \(actual)"
            
        case .buyDayOutOfRange(let actual, let min, let max):
            return "Alım günü geçersiz. Geçerli aralık: \(min)-\(max), Bulunan: \(actual)"
            
        case .emptyAllocations:
            return "Varlık dağılımı boş olamaz"
            
        case .invalidAllocation(let symbol, let weight):
            return "Geçersiz varlık dağılımı: \(symbol) (ağırlık: \(weight))"
            
        case .priceNotFound(let symbol, let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            return "\(symbol) için \(formatter.string(from: date)) tarihinde fiyat bulunamadı"
            
        case .noPriceDataAvailable(let symbol):
            return "\(symbol) için hiç fiyat verisi bulunamadı"
            
        case .simulationFailed(let reason):
            return "Simülasyon başarısız: \(reason)"
            
        case .invalidConfiguration(let reason):
            return "Geçersiz konfigürasyon: \(reason)"
        case .noInvestmentDates:
            return "Yatırım yapılabilecek tarih bulunamadı"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .invalidWeightsSum:
            return "Ağırlık toplamı 1.0 olmalıdır"
        case .monthsOutOfRange:
            return "Ay sayısı 1 veya daha büyük olmalıdır"
        case .buyDayOutOfRange:
            return "Alım günü 1-31 arasında olmalıdır"
        case .emptyAllocations:
            return "En az bir varlık dağılımı gerekli"
        case .invalidAllocation:
            return "Varlık ağırlığı 0-1 arasında olmalıdır"
        case .priceNotFound:
            return "Fiyat verisi eksik"
        case .noPriceDataAvailable:
            return "Fiyat sağlayıcısında veri yok"
        case .simulationFailed:
            return "Simülasyon motoru hatası"
        case .invalidConfiguration:
            return "Konfigürasyon hatası"
        case .noInvestmentDates:
            return "Yatırım tarihi bulunamadı"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidWeightsSum:
            return "Varlık ağırlıklarının toplamını 1.0 yapın"
        case .monthsOutOfRange:
            return "Ay sayısını 1 veya daha büyük bir değer yapın"
        case .buyDayOutOfRange:
            return "Alım gününü 1-31 arasında bir değer yapın"
        case .emptyAllocations:
            return "En az bir varlık ekleyin"
        case .invalidAllocation:
            return "Varlık ağırlığını 0-1 arasında bir değer yapın"
        case .priceNotFound:
            return "Farklı bir tarih deneyin veya fiyat sağlayıcısını kontrol edin"
        case .noPriceDataAvailable:
            return "Fiyat sağlayıcısına veri ekleyin"
        case .simulationFailed:
            return "Simülasyon parametrelerini kontrol edin"
        case .invalidConfiguration:
            return "Konfigürasyon değerlerini kontrol edin"
        case .noInvestmentDates:
            return "Tarih aralığını kontrol edin"
        }
    }
    
    public static func == (lhs: DCAError, rhs: DCAError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidWeightsSum(let lActual, let lExpected), .invalidWeightsSum(let rActual, let rExpected)):
            return lActual == rActual && lExpected == rExpected
        case (.monthsOutOfRange(let lActual, let lMin, let lMax), .monthsOutOfRange(let rActual, let rMin, let rMax)):
            return lActual == rActual && lMin == rMin && lMax == rMax
        case (.buyDayOutOfRange(let lActual, let lMin, let lMax), .buyDayOutOfRange(let rActual, let rMin, let rMax)):
            return lActual == rActual && lMin == rMin && lMax == rMax
        case (.emptyAllocations, .emptyAllocations):
            return true
        case (.invalidAllocation(let lSymbol, let lWeight), .invalidAllocation(let rSymbol, let rWeight)):
            return lSymbol == rSymbol && lWeight == rWeight
        case (.priceNotFound(let lSymbol, let lDate), .priceNotFound(let rSymbol, let rDate)):
            return lSymbol == rSymbol && lDate == rDate
        case (.noPriceDataAvailable(let lSymbol), .noPriceDataAvailable(let rSymbol)):
            return lSymbol == rSymbol
        case (.simulationFailed(let lReason), .simulationFailed(let rReason)):
            return lReason == rReason
        case (.invalidConfiguration(let lMessage), .invalidConfiguration(let rMessage)):
            return lMessage == rMessage
        default:
            return false
        }
    }
}
