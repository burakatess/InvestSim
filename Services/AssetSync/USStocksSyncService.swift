import CoreData
import Foundation

/// Service for syncing US stocks and ETFs from Supabase
@MainActor
final class USStocksSyncService {
    private let context: NSManagedObjectContext
    private let supabaseURL = "https://hplmwcjyfzjghijdqypa.supabase.co"
    private let supabaseKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwbG13Y2p5ZnpqZ2hpamRxeXBhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjY1NjEsImV4cCI6MjA3OTIwMjU2MX0.G5Cv2az01Jis-fH4P7ThakjQfVfGI8UMKwrY-hTh5k4"

    private var assetsURL: URL? {
        var components = URLComponents(string: "\(supabaseURL)/rest/v1/assets")
        components?.queryItems = [
            URLQueryItem(name: "select", value: "code,name,symbol,category"),
            URLQueryItem(name: "or", value: "(category.eq.us_stock,category.eq.us_etf)"),
        ]
        return components?.url
    }

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    /// Sync all US stocks and ETFs from Supabase
    /// - Returns: Number of assets synced
    @discardableResult
    func syncAllAssets() async throws -> Int {
        print("🔄 Starting US stocks/ETFs sync from Supabase...")

        let assets = try await fetchFromSupabase()
        print("📊 Found \(assets.count) US assets to sync")

        try await saveToDatabase(assets)

        print("✅ US stocks/ETFs sync completed: \(assets.count) assets")
        return assets.count
    }

    /// Fetch US assets from Supabase
    private func fetchFromSupabase() async throws -> [USAsset] {
        guard let url = assetsURL else {
            throw USStocksError.invalidURL
        }

        var request = URLRequest(url: url)
        request.addValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw USStocksError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ Supabase error: \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("Response: \(errorString)")
            }
            throw USStocksError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let assets = try decoder.decode([USAsset].self, from: data)

        return assets
    }

    /// Save assets to Core Data
    private func saveToDatabase(_ assets: [USAsset]) async throws {
        // Fetch existing US assets
        let fetchRequest: NSFetchRequest<AssetDefinition> = AssetDefinition.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "category IN %@", ["us_stock", "us_etf"])
        let existingAssets = try context.fetch(fetchRequest)

        // Create a map of existing assets by code
        var existingMap: [String: AssetDefinition] = [:]
        for asset in existingAssets {
            existingMap[asset.code] = asset
        }

        // Update or create assets
        for usAsset in assets {
            if let existing = existingMap[usAsset.code] {
                // Update existing
                existing.displayName = usAsset.name
                existing.symbol = usAsset.symbol
                existing.category = usAsset.category
                existing.lastSyncDate = Date()
                existing.isActive = true

                // Update metadata (sector info)
                if let metadata = usAsset.metadata {
                    existing.metadata = try? JSONEncoder().encode(metadata)
                }
            } else {
                // Create new
                let asset = AssetDefinition(context: context)
                asset.id = UUID()
                asset.code = usAsset.code
                asset.displayName = usAsset.name
                asset.symbol = usAsset.symbol
                asset.category = usAsset.category
                asset.currency = "USD"
                asset.providerType = AssetProviderType.yahoo.rawValue
                asset.yahooSymbol = usAsset.symbol  // US stocks use symbol directly
                asset.isActive = true
                asset.createdAt = Date()
                asset.lastSyncDate = Date()

                // Store metadata (sector info)
                if let metadata = usAsset.metadata {
                    asset.metadata = try? JSONEncoder().encode(metadata)
                }
            }
        }

        // Save context
        if context.hasChanges {
            try context.save()
            print("💾 Saved \(assets.count) US assets to database")
        }
    }

    /// Get last sync date for US assets
    func getLastSyncDate() -> Date? {
        let fetchRequest: NSFetchRequest<AssetDefinition> = AssetDefinition.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "category IN %@ AND lastSyncDate != nil", ["us_stock", "us_etf"])
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

/// Struct representing a US stock/ETF from Supabase
private struct USAsset: Codable {
    let code: String
    let name: String
    let symbol: String
    let category: String
    let metadata: AssetMetadataJSON?
}

/// Metadata structure for US assets
private struct AssetMetadataJSON: Codable {
    let sector: String?
}

/// Errors for US stocks sync
enum USStocksError: Error {
    case invalidURL
    case invalidResponse
    case httpError(Int)
}
