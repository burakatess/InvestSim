import Combine
import CoreData
import Foundation

struct AssetMetadata: Equatable {
    let code: AssetCode
    let displayName: String
    let symbol: String
    let category: String
    let currency: String
    let logoURL: String?
    let assetType: AssetType
    let externalId: String?
    let coingeckoId: String?
    let providerType: AssetProviderType
    let isActive: Bool
}

@MainActor
final class AssetCatalog: ObservableObject {
    static let shared = AssetCatalog()
    @Published private(set) var assets: [AssetMetadata]
    var codes: [AssetCode] { assets.map(\.code) }

    private init() {
        // Initialize with empty array first
        self.assets = []

        // Try to load from Core Data, fallback to defaults
        if let loaded = loadFromCoreData() {
            self.assets = loaded
        } else {
            self.assets = AssetDefaults.all.map { $0.toMetadata() }
        }

        print("📊 AssetCatalog initialized with \(assets.count) assets")

        // Fix missing providers for existing assets
        Task { @MainActor in
            fixMissingProviders()
        }
    }

    private func loadFromCoreData() -> [AssetMetadata]? {
        let container = CoreDataStack.shared.persistentContainer
        let context = container.viewContext

        let fetchRequest: NSFetchRequest<AssetDefinition> = AssetDefinition.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isActive == YES")
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "category", ascending: true),
            NSSortDescriptor(key: "displayName", ascending: true),
        ]

        do {
            let definitions = try context.fetch(fetchRequest)
            print("🔍 AssetCatalog: Found \(definitions.count) assets in Core Data")

            if definitions.isEmpty {
                print("⚠️ AssetCatalog: Core Data returned empty list, falling back to defaults")
                return nil
            }

            return definitions.map { definition in
                let type = AssetType(rawValue: definition.category.lowercased()) ?? .crypto
                return AssetMetadata(
                    code: AssetCode(definition.code),
                    displayName: definition.displayName,
                    symbol: definition.symbol ?? definition.code,
                    category: definition.category,
                    currency: definition.currency,
                    logoURL: definition.logoURL,
                    assetType: type,
                    externalId: definition.externalId,
                    coingeckoId: definition.coingeckoId,
                    providerType: definition.provider,
                    isActive: definition.isActive
                )
            }
        } catch {
            print("❌ AssetCatalog: Failed to fetch assets: \(error)")
            return nil
        }

    }

    /// Reload assets from Core Data
    func reloadFromDatabase() {
        if let loaded = loadFromCoreData() {
            assets = loaded
            print("🔄 AssetCatalog reloaded: \(assets.count) assets")
        }
    }

    func update(with definitions: [AssetDefinition]) {
        assets = definitions.map { definition in
            let type = AssetType(rawValue: definition.category.lowercased()) ?? .crypto
            return AssetMetadata(
                code: AssetCode(definition.code),
                displayName: definition.displayName,
                symbol: definition.symbol ?? definition.code,
                category: definition.category,
                currency: definition.currency,
                logoURL: definition.logoURL,
                assetType: type,
                externalId: definition.externalId,
                coingeckoId: definition.coingeckoId,
                providerType: definition.provider,
                isActive: definition.isActive
            )
        }
        .sorted { $0.displayName < $1.displayName }
    }

    func metadata(for code: AssetCode) -> AssetMetadata {
        if let metadata = assets.first(where: { $0.code == code }) {
            return metadata
        }
        return AssetMetadata(
            code: code,
            displayName: code.rawValue,
            symbol: code.rawValue,
            category: AssetType.crypto.rawValue,
            currency: "TRY",
            logoURL: nil,
            assetType: .crypto,
            externalId: nil,
            coingeckoId: nil,
            providerType: .unknown,
            isActive: false
        )
    }

    private func fixMissingProviders() {
        let context = CoreDataStack.shared.persistentContainer.viewContext
        var hasChanges = false

        let request: NSFetchRequest<AssetDefinition> = AssetDefinition.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")

        do {
            let assets = try context.fetch(request)

            for asset in assets {
                // Fix Currencies -> Tiingo
                if ["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "CNH", "HKD", "NZD"].contains(
                    asset.code)
                {
                    if asset.provider == .unknown || asset.provider == .local {
                        asset.providerType = AssetProviderType.tiingo.rawValue
                        hasChanges = true
                        print("🔧 Fixed provider for \(asset.code) -> Tiingo")
                    }
                }

                // Fix Commodities -> GoldAPI
                if ["ALTIN", "GUMUS"].contains(asset.code) {
                    if asset.provider == .unknown || asset.provider == .local {
                        asset.providerType = AssetProviderType.goldapi.rawValue
                        hasChanges = true
                        print("🔧 Fixed provider for \(asset.code) -> GoldAPI")
                    }
                }

                // Fix Crypto -> Binance
                if asset.category == "crypto" {
                    if asset.provider == .unknown || asset.provider == .coingecko {
                        asset.providerType = AssetProviderType.binance.rawValue
                        hasChanges = true
                        print("🔧 Fixed provider for \(asset.code) -> Binance")
                    }
                }
            }

            if hasChanges {
                try context.save()
                print("✅ Saved provider fixes to Core Data")
                reloadFromDatabase()
            }
        } catch {
            print("❌ Failed to fix providers: \(error)")
        }
    }
}

extension AssetDefaultItem {
    fileprivate func toMetadata() -> AssetMetadata {
        let type = AssetType(rawValue: category.lowercased()) ?? .crypto
        return AssetMetadata(
            code: AssetCode(code),
            displayName: displayName,
            symbol: symbol,
            category: category,
            currency: currency,
            logoURL: logoURL,
            assetType: type,
            externalId: externalId,
            coingeckoId: coingeckoId,
            providerType: providerType,
            isActive: isActive
        )
    }
}
