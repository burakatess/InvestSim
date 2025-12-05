import Combine
import CoreData
import Foundation

/// Central manager for dynamic asset catalog synchronization
@MainActor
final class AssetCatalogManager: ObservableObject {
    static let shared = AssetCatalogManager()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncStatus: String = "Not synced"
    @Published private(set) var totalAssets: Int = 0

    private let context: NSManagedObjectContext
    private let assetSyncer: USStocksSyncService

    private init() {
        let container = CoreDataStack.shared.persistentContainer
        self.context = container.viewContext
        self.assetSyncer = USStocksSyncService(context: context)

        updateTotalAssets()
        startAutoSync()
    }

    private func startAutoSync() {
        Task {
            // Give Core Data a moment to initialize
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

            updateTotalAssets()
            print("📊 AssetCatalogManager: Current asset count: \(totalAssets)")

            // Threshold for 64 assets
            if totalAssets < 60 {
                print(
                    "🚀 AssetCatalogManager: Asset count low (\(totalAssets)), triggering auto-sync..."
                )
                await syncAll()
            } else {
                print(
                    "✅ AssetCatalogManager: Asset count sufficient (\(totalAssets)), skipping auto-sync"
                )
                // Only sync if weekly schedule requires it
                await syncIfNeeded()
            }
        }
    }

    /// Sync all asset categories
    func syncAll() async {
        guard !isSyncing else {
            print("⚠️ Sync already in progress")
            return
        }

        isSyncing = true
        syncStatus = "Syncing..."

        // Ensure we reload whatever we managed to sync, even if some parts fail
        defer {
            isSyncing = false
            // Notify AssetCatalog to reload
            Task { @MainActor in
                AssetCatalog.shared.reloadFromDatabase()
            }
        }

        do {
            print("🔄 Starting full asset sync...")

            // Sync all assets from Supabase
            syncStatus = "Syncing assets from Supabase..."
            if let count = try? await assetSyncer.syncAllAssets() {
                print("✅ Synced \(count) assets from Supabase")
            }

            lastSyncDate = Date()
            updateTotalAssets()
            syncStatus = "Sync completed"

        } catch {
            print("❌ Sync failed: \(error)")
            syncStatus = "Sync failed: \(error.localizedDescription)"
        }
    }

    /// Sync only if needed (based on individual service schedules)
    func syncIfNeeded() async {
        let needsSync = assetSyncer.shouldSync()

        if needsSync {
            await syncAll()
        } else {
            print("ℹ️ No sync needed")
        }
    }

    /// Force sync all categories regardless of schedule
    func forceSync() async {
        await syncAll()
    }

    /// Get sync status for each category
    func getSyncInfo() -> SyncInfo {
        return SyncInfo(
            cryptoLastSync: assetSyncer.getLastSyncDate(),  // Use same date for both for now
            usStocksLastSync: assetSyncer.getLastSyncDate(),
            totalAssets: totalAssets
        )
    }

    private func updateTotalAssets() {
        let fetchRequest: NSFetchRequest<AssetDefinition> = AssetDefinition.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isActive == YES")

        if let count = try? context.count(for: fetchRequest) {
            totalAssets = count
        }
    }
}

/// Sync information for UI display
struct SyncInfo {
    let cryptoLastSync: Date?
    let usStocksLastSync: Date?
    let totalAssets: Int

    var formattedCryptoSync: String {
        guard let date = cryptoLastSync else { return "Never" }
        return formatRelativeDate(date)
    }

    var formattedUSStocksSync: String {
        guard let date = usStocksLastSync else { return "Never" }
        return formatRelativeDate(date)
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
