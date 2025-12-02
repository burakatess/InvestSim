import Combine
import Foundation

/// Background scheduler for automatic asset synchronization
@MainActor
final class AssetSyncScheduler {
    static let shared = AssetSyncScheduler()

    private var timer: AnyCancellable?
    private let catalogManager = AssetCatalogManager.shared
    private var isRunning = false

    private init() {}

    /// Start automatic background sync
    /// Syncs daily at 2 AM local time
    func start() {
        guard !isRunning else {
            print("⚠️ Asset sync scheduler already running")
            return
        }

        isRunning = true
        print("🚀 Starting asset sync scheduler")

        // Schedule daily sync at 2 AM
        scheduleDaily()

        // Also do an initial sync if needed
        Task {
            await catalogManager.syncIfNeeded()
        }
    }

    /// Stop automatic sync
    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
        print("🛑 Stopped asset sync scheduler")
    }

    /// Manually trigger sync
    func triggerSync() async {
        await catalogManager.syncAll()
    }

    private func scheduleDaily() {
        // Calculate next 2 AM
        let now = Date()
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 2
        components.minute = 0
        components.second = 0

        guard var nextSync = calendar.date(from: components) else {
            return
        }

        // If 2 AM has already passed today, schedule for tomorrow
        if nextSync <= now {
            nextSync = calendar.date(byAdding: .day, value: 1, to: nextSync) ?? nextSync
        }

        let timeInterval = nextSync.timeIntervalSince(now)

        print("⏰ Next asset sync scheduled for: \(nextSync)")

        // Schedule timer
        timer = Timer.publish(every: 24 * 60 * 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.catalogManager.syncIfNeeded()
                }
            }

        // Also schedule initial sync
        Task {
            try? await Task.sleep(nanoseconds: UInt64(timeInterval * 1_000_000_000))
            await catalogManager.syncIfNeeded()
        }
    }
}
