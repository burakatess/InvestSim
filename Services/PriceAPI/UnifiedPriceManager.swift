import Combine
import CoreData
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
    private let wsManager = WebSocketPriceManager()
    private let backend = BackendPriceService.shared
    private let assetService = AssetService.shared
    public let subscriptionManager = SubscriptionManager()  // Lazy subscription manager

    // ...

    // MARK: - WebSocket Management

    /// Subscribe to Supabase assets for real-time updates
    func subscribeToSupabaseAssets(_ assets: [SupabaseAsset]) {
        var cryptoSymbols: [String] = []
        var forexSymbols: [String] = []
        var usStockSymbols: [String] = []
        var yahooSymbols: [String] = []

        for asset in assets where asset.isWebsocket {
            // Default to asset code if symbol is missing
            let symbol = asset.symbol ?? asset.code

            // Determine provider
            let provider = asset.websocketProvider ?? asset.provider

            switch provider.lowercased() {
            case "binance":
                // Binance uses lowercase symbols (e.g. btcusdt)
                cryptoSymbols.append(symbol.lowercased())
            case "tiingo":
                // Tiingo uses pairs (e.g. eurusd)
                forexSymbols.append(symbol.lowercased())
            case "alpaca":
                // Alpaca uses uppercase symbols (e.g. AAPL)
                usStockSymbols.append(symbol.uppercased())
            case "yahoo":
                // Yahoo for US stocks/ETFs only
                yahooSymbols.append(symbol.uppercased())

            case "goldapi":
                // GoldAPI is polling, handled separately
                break
            default:
                break
            }
        }

        if !cryptoSymbols.isEmpty {
            wsManager.subscribe(symbols: cryptoSymbols, providerKey: "binance")
        }

        if !forexSymbols.isEmpty {
            wsManager.subscribe(symbols: forexSymbols, providerKey: "tiingo")
        }

        if !usStockSymbols.isEmpty {
            wsManager.subscribe(symbols: usStockSymbols, providerKey: "alpaca")
        }

        if !yahooSymbols.isEmpty {
            wsManager.subscribe(symbols: yahooSymbols, providerKey: "yahoo")
        }

        print(
            "📡 Subscribed to assets: \(cryptoSymbols.count) Crypto, \(forexSymbols.count) Forex, \(usStockSymbols.count) US Stocks, \(yahooSymbols.count) Yahoo"
        )
    }
    private var cancellables = Set<AnyCancellable>()

    // Cache
    private var priceCache: [String: (price: Double, timestamp: Date)] = [:]

    // Publishers
    public let priceUpdatePublisher = PassthroughSubject<PriceUpdate, Never>()

    private init() {
        print("✅ UnifiedPriceManager initializing...")
        setupWebSocketProviders()
        setupPriceUpdateListener()
    }

    deinit {
        Task { @MainActor in
            wsManager.disconnectAll()
        }
        cancellables.removeAll()
        print("🧹 UnifiedPriceManager deinitialized")
    }

    // MARK: - Setup
    private func setupWebSocketProviders() {
        let apiKeyManager = APIKeyManager.shared

        // 1. Binance (Crypto) ✅
        let binanceProvider = BinanceWebSocketProvider()
        wsManager.addProvider(binanceProvider, withKey: "binance")
        subscriptionManager.registerProvider(binanceProvider, forType: "binance")
        subscriptionManager.registerProvider(binanceProvider, forType: "coingecko")  // Map coingecko to binance

        // 2. Tiingo (Forex) 💱
        if let tiingoKey = apiKeyManager.getAPIKey(for: "tiingo"), !tiingoKey.isEmpty {
            let tiingoProvider = TiingoWebSocketProvider(apiKey: tiingoKey)
            wsManager.addProvider(tiingoProvider, withKey: "tiingo")
            subscriptionManager.registerProvider(tiingoProvider, forType: "tiingo")
            print("✅ Tiingo provider added")
        } else {
            print("⚠️ Tiingo API key not found - Forex WebSocket disabled")
        }

        // 3. GoldAPI (Commodities) 🥇
        if let goldAPIKey = apiKeyManager.getAPIKey(for: "goldapi"), !goldAPIKey.isEmpty {
            let goldProvider = GoldAPIProvider(apiKey: goldAPIKey)
            wsManager.addProvider(goldProvider, withKey: "goldapi")
            // GoldAPI is polling, but we register it to handle subscriptions (even if no-op or polling start)
            // Assuming GoldAPIProvider conforms to SubscribableProvider
            if let subscribable = goldProvider as? SubscribableProvider {
                subscriptionManager.registerProvider(subscribable, forType: "goldapi")
            }
            print("✅ GoldAPI provider added")
        } else {
            print("⚠️ GoldAPI key not found - Commodities polling disabled")
        }

        // 4. Alpaca (US Stocks) 📈
        if let alpacaKey = apiKeyManager.getAPIKey(for: "alpaca_key"),
            let alpacaSecret = apiKeyManager.getAPIKey(for: "alpaca_secret"),
            !alpacaKey.isEmpty, !alpacaSecret.isEmpty
        {
            let alpacaProvider = AlpacaWebSocketProvider(
                apiKey: alpacaKey,
                apiSecret: alpacaSecret
            )
            wsManager.addProvider(alpacaProvider, withKey: "alpaca")
            subscriptionManager.registerProvider(alpacaProvider, forType: "alpaca")
            print("✅ Alpaca provider added")
        } else {
            print("⚠️ Alpaca credentials not found - US Stocks WebSocket disabled")
        }

        // 5. Yahoo Finance (US Stocks & ETFs) 📈
        let yahooProvider = YahooFinanceProvider()
        wsManager.addProvider(yahooProvider, withKey: "yahoo")
        subscriptionManager.registerProvider(yahooProvider, forType: "yahoo")
        print("✅ Yahoo Finance provider added")

        // Auto-connect providers on initialization
        wsManager.connectAll()

        // Register placeholders
        let placeholder = PlaceholderWebSocketProvider()
        subscriptionManager.registerProvider(placeholder, forType: "local")
        subscriptionManager.registerProvider(placeholder, forType: "unknown")

        print("📡 WebSocket providers configured and registered with SubscriptionManager")
    }

    private func setupPriceUpdateListener() {
        wsManager.priceUpdatePublisher
            .sink { [weak self] (update: PriceUpdate) in
                self?.handlePriceUpdate(update)
            }
            .store(in: &cancellables)
    }

    private func handlePriceUpdate(_ update: PriceUpdate) {
        priceCache[update.assetCode] = (update.price, Date())
        priceUpdatePublisher.send(update)
        print("💰 Price updated: \(update.assetCode) = \(update.price) (from \(update.source))")
    }

    // MARK: - Public API

    /// Get price for asset code
    func price(for assetCode: String) async throws -> Double {
        // 1. Check cache (WebSocket data)
        if let cached = priceCache[assetCode],
            Date().timeIntervalSince(cached.timestamp) < 60
        {
            return cached.price
        }

        // 2. Fallback to Supabase
        if let backendPrice = try await backend.fetchPrice(for: assetCode) {
            let price = NSDecimalNumber(decimal: backendPrice.price).doubleValue
            priceCache[assetCode] = (price, Date())

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

    /// Fetch historical prices for an asset
    func historicalPrices(for asset: AssetDefinition, start: Date, end: Date) async throws
        -> [BackendPrice]
    {
        // Use asset code for backend lookup
        return try await backend.fetchHistoricalPrices(for: asset.code, start: start, end: end)
    }

    // MARK: - WebSocket Management
    // subscribeToAssets() temporarily disabled - requires AssetService
    // Will re-enable when Supabase integration is complete

    /// Get WebSocket connection states
    func getWebSocketStates() -> [String: ConnectionState] {
        return wsManager.connectionStates
    }
}

/// A placeholder provider that does nothing but satisfies the SubscribableProvider protocol.
/// Used for 'local', 'unknown', or other providers that don't have a real implementation yet.
final class PlaceholderWebSocketProvider: SubscribableProvider {
    var isConnected: Bool = true

    func subscribe(symbols: [String]) {
        // No-op
        print("Placeholder provider subscribed to: \(symbols)")
    }

    func unsubscribe(symbols: [String]) {
        // No-op
    }
}
