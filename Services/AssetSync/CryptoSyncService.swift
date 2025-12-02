import CoreData
import Foundation

@MainActor
final class CryptoSyncService {
    private let client = CoinGeckoAPIClient()
    private let context: NSManagedObjectContext
    private let targetCount: Int

    init(context: NSManagedObjectContext, targetCount: Int = 750) {
        self.context = context
        self.targetCount = targetCount
    }

    /// Sync top cryptocurrencies by market cap
    /// - Returns: Number of cryptocurrencies synced
    @discardableResult
    func syncTopCryptos() async throws -> Int {
        print("🔄 Starting crypto sync for top \(targetCount) cryptocurrencies...")

        var allCoins: [CoinGeckoMarket] = []
        let perPage = 250
        let totalPages = (targetCount + perPage - 1) / perPage  // Ceiling division

        // Fetch all pages
        for page in 1...totalPages {
            do {
                print("📥 Fetching page \(page)/\(totalPages)...")
                let coins = try await client.fetchMarkets(
                    vsCurrency: "usd",
                    order: "market_cap_desc",
                    perPage: perPage,
                    page: page
                )
                allCoins.append(contentsOf: coins)

                // Rate limiting: wait 2 seconds between requests (30 calls/min = 1 call/2s)
                if page < totalPages {
                    try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
                }
            } catch {
                print("❌ Failed to fetch page \(page): \(error)")
                throw error
            }
        }

        // Limit to target count
        let coinsToSync = Array(allCoins.prefix(targetCount))
        print("✅ Fetched \(coinsToSync.count) cryptocurrencies")

        // Save to Core Data
        try await saveToDatabase(coinsToSync)

        print("✅ Crypto sync completed: \(coinsToSync.count) cryptocurrencies")
        return coinsToSync.count
    }

    private func saveToDatabase(_ coins: [CoinGeckoMarket]) async throws {
        // Fetch existing crypto assets
        let fetchRequest: NSFetchRequest<AssetDefinition> = AssetDefinition.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "category == %@", "crypto")
        let existingAssets = try context.fetch(fetchRequest)

        // Create a map of existing assets by coingeckoId
        var existingMap: [String: AssetDefinition] = [:]
        for asset in existingAssets {
            if let id = asset.coingeckoId {
                existingMap[id] = asset
            }
        }

        // Update or create assets
        for coin in coins {
            if let existing = existingMap[coin.id] {
                // Update existing
                existing.displayName = coin.name
                existing.symbol = coin.symbol.uppercased()
                existing.marketCapRank = Int32(coin.marketCapRank ?? 0)
                existing.logoURL = coin.image
                existing.lastSyncDate = Date()
                existing.isActive = true
            } else {
                // Create new
                let asset = AssetDefinition(context: context)
                asset.id = UUID()
                asset.code = coin.symbol.uppercased()
                asset.displayName = coin.name
                asset.symbol = coin.symbol.uppercased()
                asset.category = "crypto"
                asset.currency = "USD"
                asset.logoURL = coin.image
                asset.coingeckoId = coin.id
                asset.providerType = AssetProviderType.coingecko.rawValue
                asset.marketCapRank = Int32(coin.marketCapRank ?? 0)
                asset.isActive = true
                asset.createdAt = Date()
                asset.lastSyncDate = Date()
            }
        }

        // Deactivate cryptos not in top list anymore
        let syncedIds = Set(coins.map { $0.id })
        for asset in existingAssets {
            if let id = asset.coingeckoId, !syncedIds.contains(id) {
                asset.isActive = false
            }
        }

        // Save context
        if context.hasChanges {
            try context.save()
            print("💾 Saved \(coins.count) cryptocurrencies to database")
        }
    }

    /// Get last sync date for crypto assets
    func getLastSyncDate() -> Date? {
        let fetchRequest: NSFetchRequest<AssetDefinition> = AssetDefinition.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "category == %@ AND lastSyncDate != nil", "crypto")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastSyncDate", ascending: false)]
        fetchRequest.fetchLimit = 1

        guard let asset = try? context.fetch(fetchRequest).first else {
            return nil
        }
        return asset.lastSyncDate
    }

    /// Check if sync is needed (weekly)
    func shouldSync() -> Bool {
        guard let lastSync = getLastSyncDate() else {
            return true  // Never synced
        }

        let weekInSeconds: TimeInterval = 7 * 24 * 60 * 60
        return Date().timeIntervalSince(lastSync) > weekInSeconds
    }
}
