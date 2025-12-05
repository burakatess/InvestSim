import CoreData
import Foundation

/// Service for syncing all assets from Supabase
@MainActor
final class USStocksSyncService {
    private let context: NSManagedObjectContext
    private let supabaseURL = "https://hplmwcjyfzjghijdqypa.supabase.co"
    private let supabaseKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwbG13Y2p5ZnpqZ2hpamRxeXBhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjY1NjEsImV4cCI6MjA3OTIwMjU2MX0.G5Cv2az01Jis-fH4P7ThakjQfVfGI8UMKwrY-hTh5k4"

    private var assetsURL: URL? {
        var components = URLComponents(string: "\(supabaseURL)/rest/v1/assets")
        components?.queryItems = [
            URLQueryItem(
                name: "select", value: "code,name,symbol,category,type,provider_id,currency")
            // Fetch all active assets (no type filter)
        ]
        return components?.url
    }

    // ... (existing code)

    /// Struct representing an asset from Supabase
    private struct SyncSupabaseAsset: Codable {
        let code: String
        let name: String
        let symbol: String
        let type: String
        let providerId: String?
        let currency: String?
        let metadata: AssetMetadataJSON?
    }

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    /// Sync all assets from Supabase
    /// - Returns: Number of assets synced
    @discardableResult
    func syncAllAssets() async throws -> Int {
        print("🔄 Starting full asset sync from Supabase...")

        let assets = try await fetchFromSupabase()
        print("📊 Found \(assets.count) assets to sync")

        try await saveToDatabase(assets)

        print("✅ Asset sync completed: \(assets.count) assets")
        return assets.count
    }

    /// Fetch assets from Supabase
    private func fetchFromSupabase() async throws -> [SyncSupabaseAsset] {
        guard let url = assetsURL else {
            throw SyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.addValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ Supabase error: \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("Response: \(errorString)")
            }
            throw SyncError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let assets = try decoder.decode([SyncSupabaseAsset].self, from: data)

        return assets
    }

    /// Save assets to Core Data
    private func saveToDatabase(_ assets: [SyncSupabaseAsset]) async throws {
        // Fetch existing assets
        let fetchRequest: NSFetchRequest<AssetDefinition> = AssetDefinition.fetchRequest()
        let existingAssets = try context.fetch(fetchRequest)

        // Create a map of existing assets by code
        var existingMap: [String: AssetDefinition] = [:]
        for asset in existingAssets {
            existingMap[asset.code] = asset
        }

        // Track synced assets to identify stale ones
        var syncedCodes = Set<String>()

        // Update or create assets
        for remoteAsset in assets {
            syncedCodes.insert(remoteAsset.code)

            if let existing = existingMap[remoteAsset.code] {
                // Update existing
                updateAsset(existing, with: remoteAsset)
            } else {
                // Create new
                let asset = AssetDefinition(context: context)
                asset.id = UUID()
                asset.createdAt = Date()
                updateAsset(asset, with: remoteAsset)
            }
        }

        // Deactivate stale assets (those not in the current sync)
        for asset in existingAssets {
            if !syncedCodes.contains(asset.code) {
                if asset.isActive {
                    print("⚠️ Deactivating stale asset: \(asset.code)")
                    asset.isActive = false
                }
            }
        }

        // Save context
        if context.hasChanges {
            try context.save()
            print("💾 Saved \(assets.count) assets to database")
        }
    }

    private func updateAsset(_ asset: AssetDefinition, with remote: SyncSupabaseAsset) {
        asset.code = remote.code
        asset.displayName = remote.name
        asset.symbol = remote.symbol

        // Map Supabase type to AssetType rawValue
        switch remote.type {
        case "stock": asset.category = "us_stock"
        case "etf": asset.category = "us_etf"
        case "fx": asset.category = "forex"
        case "metal": asset.category = "commodity"
        default: asset.category = remote.type
        }

        // Use remote currency if available, otherwise fallback
        if let remoteCurrency = remote.currency, !remoteCurrency.isEmpty {
            asset.currency = remoteCurrency
        } else {
            asset.currency = determineCurrency(for: remote.type)
        }

        asset.providerType = determineProviderType(for: remote.type)
        asset.isActive = true
        asset.lastSyncDate = Date()

        // Map specific fields
        if remote.type == "crypto" {
            asset.coingeckoId = remote.providerId  // Use provider_id as coingeckoId/identifier
        } else {
            asset.yahooSymbol = remote.symbol
        }

        if let metadata = remote.metadata {
            asset.metadata = try? JSONEncoder().encode(metadata)
        }
    }

    private func determineCurrency(for type: String) -> String {
        switch type {
        case "crypto", "stock", "etf", "metal": return "USD"
        case "fx": return "TRY"  // Default to TRY for now based on seed (USDTRY etc)
        default: return "USD"
        }
    }

    private func determineProviderType(for type: String) -> String {
        switch type {
        case "crypto": return "binance"
        case "stock", "etf", "metal", "fx": return "yahoo"
        default: return "yahoo"
        }
    }

    /// Get last sync date
    func getLastSyncDate() -> Date? {
        let fetchRequest: NSFetchRequest<AssetDefinition> = AssetDefinition.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "lastSyncDate != nil")
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

/// Metadata structure
private struct AssetMetadataJSON: Codable {
    let sector: String?
}

/// Errors for sync
enum SyncError: Error {
    case invalidURL
    case invalidResponse
    case httpError(Int)
}
