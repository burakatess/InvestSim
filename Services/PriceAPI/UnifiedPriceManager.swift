import Combine
import Foundation

public enum UnifiedPriceError: Error {
    case unsupportedAsset
    case noProviderAvailable
    case networkError
    case cacheError
    case missingIdentifier
    case historicalDataUnavailable
}

@MainActor
final class UnifiedPriceManager {
    static let shared = UnifiedPriceManager()

    // Services
    private let backend = BackendPriceService.shared

    // Publishers
    public let priceUpdatePublisher = PassthroughSubject<PriceUpdate, Never>()

    // Cache
    private var priceCache: [String: (price: Double, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 10.0

    private init() {
        print("✅ UnifiedPriceManager initializing (Backend-First Mode)...")
    }

    // MARK: - Public API

    /// Get price for single asset code
    func price(for assetCode: String) async throws -> Double {
        // Check cache first
        let now = Date()
        if let cached = priceCache[assetCode], now.timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.price
        }

        // Fetch from backend
        if let backendPrice = try await backend.fetchPrice(for: assetCode) {
            let price = NSDecimalNumber(decimal: backendPrice.price).doubleValue

            // Update cache
            priceCache[assetCode] = (price, now)

            // Notify listeners
            let update = PriceUpdate(
                assetCode: assetCode,
                price: price,
                source: "supabase",
                volume: nil
            )
            priceUpdatePublisher.send(update)
            return price
        }

        throw UnifiedPriceError.noProviderAvailable
    }

    /// Batch fetch prices for multiple asset codes
    func fetchPrices(for assetCodes: [String]) async throws -> [String: Double] {
        var results: [String: Double] = [:]
        let now = Date()

        // Check which codes need fetching
        var codesToFetch: [String] = []
        for code in assetCodes {
            if let cached = priceCache[code], now.timeIntervalSince(cached.timestamp) < cacheTTL {
                results[code] = cached.price
            } else {
                codesToFetch.append(code)
            }
        }

        // If all cached, return early
        if codesToFetch.isEmpty {
            return results
        }

        // Fetch missing from backend
        let backendPrices = try await backend.fetchPrices(symbols: codesToFetch)

        for bp in backendPrices {
            let price = NSDecimalNumber(decimal: bp.price).doubleValue
            results[bp.assetCode] = price

            // Update cache
            priceCache[bp.assetCode] = (price, now)

            // Notify listeners
            let update = PriceUpdate(
                assetCode: bp.assetCode,
                price: price,
                source: "supabase",
                volume: nil
            )
            priceUpdatePublisher.send(update)
        }

        return results
    }

    /// Fetch all prices (no filter)
    func fetchAllPrices() async throws -> [String: Double] {
        var results: [String: Double] = [:]
        let now = Date()

        let backendPrices = try await backend.fetchAllPrices()

        for bp in backendPrices {
            let price = NSDecimalNumber(decimal: bp.price).doubleValue
            results[bp.assetCode] = price

            // Update cache
            priceCache[bp.assetCode] = (price, now)
        }

        print("✅ Fetched \(results.count) prices from backend")
        return results
    }

    /// Fetch historical prices for an asset
    func historicalPrices(for assetCode: String, range: String = "1m") async throws -> [(
        date: String, close: Double
    )] {
        let items = try await backend.fetchHistoricalPrices(for: assetCode, range: range)
        return items.map { (date: $0.date, close: $0.close) }
    }

    /// Clear price cache
    func clearCache() {
        priceCache.removeAll()
        backend.clearCache()
    }
}
