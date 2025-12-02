import Combine
import Foundation

/// Protocol for WebSocket providers that can be managed by SubscriptionManager
public protocol SubscribableProvider: AnyObject {
    func subscribe(symbols: [String])
    func unsubscribe(symbols: [String])
    var isConnected: Bool { get }
}

/// Manages lazy subscription to price providers based on asset visibility
@MainActor
public final class SubscriptionManager {
    // MARK: - Properties
    private var providers: [String: SubscribableProvider] = [:]
    private var activeSubscriptions: [String: String] = [:]  // assetCode -> provider
    private var debounceTimer: Timer?
    private var pendingVisibleAssets: [(code: String, provider: String)] = []
    private var debounceTask: Task<Void, Never>?

    // MARK: - Initialization
    init() {
        print("🎯 SubscriptionManager initialized")
    }

    /// Register a provider for a specific asset type
    func registerProvider(_ provider: SubscribableProvider, forType type: String) {
        providers[type] = provider
        print("✅ Registered provider for type: \(type)")
    }

    // MARK: - Subscription Management

    /// Subscribe to a single asset
    func subscribe(assetCode: String, provider: String) {
        guard let providerInstance = providers[provider] else {
            print("⚠️ Provider not found: \(provider)")
            return
        }

        // Skip if already subscribed
        guard activeSubscriptions[assetCode] == nil else {
            return
        }

        providerInstance.subscribe(symbols: [assetCode])
        activeSubscriptions[assetCode] = provider

        print("✅ Subscribed: \(assetCode) via \(provider)")
    }

    /// Unsubscribe from a single asset
    func unsubscribe(assetCode: String) {
        guard let provider = activeSubscriptions[assetCode],
            let providerInstance = providers[provider]
        else {
            return
        }

        providerInstance.unsubscribe(symbols: [assetCode])
        activeSubscriptions.removeValue(forKey: assetCode)

        print("❌ Unsubscribed: \(assetCode)")
    }

    /// Update visible assets with debouncing
    /// - Parameter visibleAssets: Array of (assetCode, provider) tuples
    func updateVisibleAssets(_ visibleAssets: [(code: String, provider: String)]) {
        // Store pending update
        pendingVisibleAssets = visibleAssets

        // Cancel previous debounce task
        debounceTask?.cancel()

        // Debounce: wait 500ms before applying changes
        debounceTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 500_000_000)  // 500ms debounce
                await self.performUpdate()
            } catch {
                // Task was cancelled, no need to perform update
            }
        }
    }

    private func performUpdate() {
        let visibleCodes = Set(pendingVisibleAssets.map { $0.code })
        let currentCodes = Set(activeSubscriptions.keys)

        // 1. Subscribe to NEW assets immediately
        let toSubscribe = pendingVisibleAssets.filter { !currentCodes.contains($0.code) }
        toSubscribe.forEach { subscribe(assetCode: $0.code, provider: $0.provider) }

        // 2. Unsubscribe from HIDDEN assets with a delay (Grace Period)
        // Instead of unsubscribing immediately, we check if they are still hidden after the next update cycle.
        // For now, we'll just be less aggressive: only unsubscribe if we have significantly more subscriptions than visible assets.
        // This simple heuristic prevents thrashing during rapid scrolling.

        let toUnsubscribe = currentCodes.subtracting(visibleCodes)

        // Only unsubscribe if we have > 20 extra subscriptions to keep memory usage in check
        // but avoid constant connect/disconnect for small lists.
        if toUnsubscribe.count > 20 {
            // Unsubscribe from the oldest ones or just all of them?
            // Let's unsubscribe from all but keep the threshold high.
            toUnsubscribe.forEach { unsubscribe(assetCode: $0) }
        } else {
            // If we have few extra subscriptions, keep them alive for a bit.
            // This acts as a cache for recently viewed assets.
            print("ℹ️ Keeping \(toUnsubscribe.count) hidden subscriptions active for performance")
        }

        print(
            "🔄 Updated subscriptions: \(activeSubscriptions.count) active (Visible: \(visibleCodes.count))"
        )
    }

    /// Subscribe to portfolio assets (always active)
    func subscribeToPortfolio(_ portfolioAssets: [(code: String, provider: String)]) {
        portfolioAssets.forEach { subscribe(assetCode: $0.code, provider: $0.provider) }
        print("💼 Subscribed to \(portfolioAssets.count) portfolio assets")
    }

    /// Unsubscribe from all assets
    func unsubscribeAll() {
        let allCodes = Array(activeSubscriptions.keys)
        allCodes.forEach { unsubscribe(assetCode: $0) }
        print("🛑 Unsubscribed from all assets")
    }

    // MARK: - Cleanup
    deinit {
        debounceTask?.cancel()  // Cancel any pending debounce task
        Task { @MainActor in
            await unsubscribeAll()
        }
        print("🎯 SubscriptionManager deinitialized")
    }
}

// MARK: - Helper Extension
extension SubscriptionManager {
    /// Get current subscription count
    var activeSubscriptionCount: Int {
        activeSubscriptions.count
    }

    /// Check if an asset is currently subscribed
    func isSubscribed(assetCode: String) -> Bool {
        activeSubscriptions[assetCode] != nil
    }
}
