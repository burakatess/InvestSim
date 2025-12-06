import Foundation

public enum AssetType: String, Codable, CaseIterable {
    case forex
    case crypto
    case commodity
    case us_stock = "us_stock"
    case us_etf = "us_etf"

    public var displayName: String {
        switch self {
        case .forex: return "Forex"
        case .crypto: return "Crypto"
        case .commodity: return "Commodity"
        case .us_stock: return "US Stocks"
        case .us_etf: return "US ETF"
        }
    }

    public var fallbackIcon: String {
        switch self {
        case .crypto: return "bitcoinsign.circle.fill"
        case .forex: return "dollarsign.circle.fill"
        case .commodity: return "diamond.fill"
        case .us_stock: return "flag.fill"
        case .us_etf: return "chart.bar.fill"
        }
    }

    /// Map to database asset_class values
    public var dbCategory: String {
        switch self {
        case .forex: return "fx"
        case .crypto: return "crypto"
        case .commodity: return "metal"
        case .us_stock: return "stock"
        case .us_etf: return "etf"
        }
    }

    /// Initialize from database asset_class value
    public static func fromDBCategory(_ dbValue: String) -> AssetType? {
        switch dbValue.lowercased() {
        case "fx": return .forex
        case "crypto": return .crypto
        case "metal": return .commodity
        case "stock": return .us_stock
        case "etf": return .us_etf
        default: return nil
        }
    }
}

public enum AssetProviderType: String, Codable, CaseIterable {
    case unknown = "unknown"
    case yahoo = "yahoo"
    case binance = "binance"
    case tiingo = "tiingo"
    case goldapi = "goldapi"
    case alpaca = "alpaca"
    case tefas = "tefas"
    case coingecko = "coingecko"
    case local = "local"
}

public struct AssetCode: Hashable, Codable, RawRepresentable, ExpressibleByStringLiteral,
    Identifiable, CaseIterable
{
    public let rawValue: String
    public var id: String { rawValue }

    public init(rawValue: String) {
        self.rawValue = rawValue.uppercased()
    }

    public init(_ value: String) {
        self.rawValue = value.uppercased()
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value.uppercased()
    }

    public static var allCases: [AssetCode] {
        AssetCatalog.shared.codes
    }
}

extension AssetCode {
    var displayName: String {
        AssetCatalog.shared.metadata(for: self).displayName
    }

    var symbol: String {
        AssetCatalog.shared.metadata(for: self).symbol
    }

    var currency: String {
        AssetCatalog.shared.metadata(for: self).currency
    }

    var assetType: AssetType {
        AssetCatalog.shared.metadata(for: self).assetType
    }

    var logoURL: String? {
        AssetCatalog.shared.metadata(for: self).logoURL
    }

    var fallbackIcon: String {
        assetType.fallbackIcon
    }
}

// Legacy static codes for backwards compatibility
extension AssetCode {
    static let USD: AssetCode = "USD"
    static let EUR: AssetCode = "EUR"
    static let GBP: AssetCode = "GBP"
    static let AUD: AssetCode = "AUD"
    static let CAD: AssetCode = "CAD"
    static let CHF: AssetCode = "CHF"
    static let CNH: AssetCode = "CNH"
    static let HKD: AssetCode = "HKD"
    static let NZD: AssetCode = "NZD"
    static let JPY: AssetCode = "JPY"
    // Turkish assets removed
    static let BTC: AssetCode = "BTC"
    static let ETH: AssetCode = "ETH"
    static let BNB: AssetCode = "BNB"
    static let XRP: AssetCode = "XRP"
    static let ADA: AssetCode = "ADA"
    static let DOGE: AssetCode = "DOGE"
    static let SOL: AssetCode = "SOL"
    static let MATIC: AssetCode = "MATIC"
    static let DOT: AssetCode = "DOT"
    static let AVAX: AssetCode = "AVAX"
    static let LTC: AssetCode = "LTC"
    static let UNI: AssetCode = "UNI"
    static let LINK: AssetCode = "LINK"
    static let ATOM: AssetCode = "ATOM"
    static let ETC: AssetCode = "ETC"
    static let XLM: AssetCode = "XLM"
    static let ALGO: AssetCode = "ALGO"
    static let VET: AssetCode = "VET"
    static let ICP: AssetCode = "ICP"
    static let FIL: AssetCode = "FIL"
}

struct Asset: Identifiable, Codable, Equatable {
    var id = UUID()
    let code: AssetCode
    let name: String
    let symbol: String
    let currency: String
    let assetType: AssetType

    init(code: AssetCode) {
        self.code = code
        let metadata = AssetCatalog.shared.metadata(for: code)
        self.name = metadata.displayName
        self.symbol = metadata.symbol
        self.currency = metadata.currency
        self.assetType = metadata.assetType
    }
}
