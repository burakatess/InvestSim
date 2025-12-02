import Combine
import Foundation

/// Varlık dağılımını temsil eden model
/// DCA simülasyonunda hangi varlığa ne kadar yatırım yapılacağını belirler
internal class AssetAllocation: Identifiable, Codable, Equatable, ObservableObject {
    internal let id = UUID()
    internal let assetCode: AssetCode
    internal var weight: Decimal {  // 0.0 - 1.0 arası (0% - 100%)
        didSet {
            objectWillChange.send()
        }
    }
    internal var isEnabled: Bool

    // ObservableObject için gerekli
    internal let objectWillChange = PassthroughSubject<Void, Never>()

    // Codable için custom coding keys
    private enum CodingKeys: String, CodingKey {
        case id, assetCode, weight, isEnabled
    }

    internal init(assetCode: AssetCode, weight: Decimal, isEnabled: Bool = true) {
        self.assetCode = assetCode
        self.weight = weight
        self.isEnabled = isEnabled
    }

    /// Yüzde olarak ağırlık döndürür
    internal var weightPercentage: Decimal {
        return weight * 100
    }

    /// Ağırlık yüzdesini string olarak döndürür
    internal var weightPercentageString: String {
        return String(format: "%.1f%%", Double(truncating: weightPercentage as NSNumber))
    }

    // MARK: - Equatable

    static func == (lhs: AssetAllocation, rhs: AssetAllocation) -> Bool {
        return lhs.id == rhs.id && lhs.assetCode == rhs.assetCode && lhs.weight == rhs.weight
            && lhs.isEnabled == rhs.isEnabled
    }
}

/// Varlık kategorileri
internal enum AssetCategory: String, CaseIterable, Codable {
    case crypto = "crypto"
    case forex = "forex"
    case commodity = "commodity"

    case us_stock = "us_stock"
    case us_etf = "us_etf"

    internal var displayName: String {
        switch self {
        case .crypto: return "Crypto"
        case .forex: return "Forex"
        case .commodity: return "Commodities"
        case .us_stock: return "US Stocks"
        case .us_etf: return "US ETFs"
        }
    }

    internal var icon: String {
        switch self {
        case .crypto: return "bitcoinsign.circle.fill"
        case .forex: return "dollarsign.circle.fill"
        case .commodity: return "circle.grid.cross.fill"
        case .us_stock: return "flag.fill"
        case .us_etf: return "chart.bar.fill"
        }
    }
}

/// Varlık seçimi için kullanılan model
internal struct SelectableAsset: Identifiable, Codable, Equatable {
    internal let id = UUID()
    internal let assetCode: AssetCode
    internal let category: AssetCategory
    internal let displayName: String
    internal let symbol: String
    internal let isPopular: Bool  // Popüler varlıklar için

    internal init(
        assetCode: AssetCode, category: AssetCategory, displayName: String, symbol: String,
        isPopular: Bool = false
    ) {
        self.assetCode = assetCode
        self.category = category
        self.displayName = displayName
        self.symbol = symbol
        self.isPopular = isPopular
    }
}

/// Varlık seçimi için yardımcı sınıf
internal class AssetSelectionHelper {
    internal static let shared = AssetSelectionHelper()

    private init() {}

    // MARK: - Sorting & Sector
    internal enum AssetSort: String, CaseIterable { case popular, nameAZ, symbolAZ }

    /// Tüm seçilebilir varlıkları döndürür
    internal func getAllSelectableAssets() -> [SelectableAsset] {
        return AssetCatalog.shared.assets
            .filter { $0.isActive }
            .map { metadata in
                let category = AssetCategory(rawValue: metadata.assetType.rawValue) ?? .crypto
                let isPopular = AssetDefaults.popularCodes.contains(metadata.code.rawValue)
                return SelectableAsset(
                    assetCode: metadata.code,
                    category: category,
                    displayName: metadata.displayName,
                    symbol: metadata.symbol,
                    isPopular: isPopular
                )
            }
    }

    /// Kategoriye göre varlıkları filtreler
    internal func getAssetsByCategory(_ category: AssetCategory) -> [SelectableAsset] {
        return getAllSelectableAssets().filter { $0.category == category }
    }

    /// Sıralama uygular
    internal func sort(_ list: [SelectableAsset], by sort: AssetSort) -> [SelectableAsset] {
        switch sort {
        case .popular:
            return list.sorted { ($0.isPopular ? 1 : 0) > ($1.isPopular ? 1 : 0) }
        case .nameAZ:
            return list.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        case .symbolAZ:
            return list.sorted {
                $0.symbol.localizedCaseInsensitiveCompare($1.symbol) == .orderedAscending
            }
        }
    }

    /// Popüler varlıkları döndürür
    internal func getPopularAssets() -> [SelectableAsset] {
        return getAllSelectableAssets().filter { $0.isPopular }
    }

    // MARK: - Recent selections (persisted)
    private let recentKey = "asset_picker_recent_codes"
    private let maxRecent = 12

    internal func recordRecent(_ code: AssetCode) {
        var arr = (UserDefaults.standard.array(forKey: recentKey) as? [String]) ?? []
        arr.removeAll { $0 == code.rawValue }
        arr.insert(code.rawValue, at: 0)
        if arr.count > maxRecent { arr = Array(arr.prefix(maxRecent)) }
        UserDefaults.standard.set(arr, forKey: recentKey)
    }

    internal func getRecentAssets() -> [SelectableAsset] {
        let codes = (UserDefaults.standard.array(forKey: recentKey) as? [String]) ?? []
        let all = getAllSelectableAssets()
        var map: [String: SelectableAsset] = [:]
        all.forEach { map[$0.assetCode.rawValue] = $0 }
        return codes.compactMap { map[$0] }
    }
}
