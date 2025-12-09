// Services/Backend/BackendPriceService.swift
// Updated for Supabase Backend v2.0
import Foundation

// MARK: - Response Models (New API)

/// Response from /prices-latest endpoint
struct PricesLatestResponse: Codable {
    let count: Int
    let prices: [PriceItem]
}

struct PriceItem: Codable {
    let symbol: String
    let displayName: String
    let assetClass: String  // "crypto", "stock", "etf", "fx", "metal"
    let currency: String
    let price: Double?
    let percentChange24h: Double?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case displayName
        case assetClass = "class"
        case currency
        case price
        case percentChange24h
        case updatedAt
    }
}

/// Response from /prices-history endpoint
struct PricesHistoryResponse: Codable {
    let symbol: String
    let range: String
    let count: Int
    let data: [OHLCVItem]
}

struct OHLCVItem: Codable {
    let date: String
    let open: Double?
    let high: Double?
    let low: Double?
    let close: Double
    let volume: Double?
}

// MARK: - Internal Model
struct BackendPrice {
    let assetCode: String
    let displayName: String
    let assetClass: String
    let price: Decimal
    let change24h: Double?
    let currency: String
    let updatedAt: Date
}

// MARK: - Backend Price Service
@MainActor
class BackendPriceService {
    static let shared = BackendPriceService()

    // Supabase Configuration
    private let baseURL = "https://hplmwcjyfzjghijdqypa.supabase.co/functions/v1"
    private let apiKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwbG13Y2p5ZnpqZ2hpamRxeXBhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjY1NjEsImV4cCI6MjA3OTIwMjU2MX0.G5Cv2az01Jis-fH4P7ThakjQfVfGI8UMKwrY-hTh5k4"

    private let session: URLSession
    private let decoder: JSONDecoder

    // Memory Cache with TTL
    private var priceCache: [String: (price: BackendPrice, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 10.0  // 10 seconds cache

    // Debounce
    private var isFetching = false

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
    }

    // MARK: - Fetch All Prices

    /// Fetch all active asset prices from the backend
    func fetchAllPrices() async throws -> [BackendPrice] {
        return try await fetchPrices(symbols: nil)
    }

    /// Fetch prices for specific symbols
    func fetchPrices(symbols: [String]? = nil) async throws -> [BackendPrice] {
        // Prevent concurrent fetches
        guard !isFetching else {
            print("⏸️ Skipping fetch - already in progress")
            return getCachedPrices(for: symbols ?? [])
        }

        isFetching = true
        defer { isFetching = false }

        // Build URL
        var urlString = "\(baseURL)/prices-latest"
        if let symbols = symbols, !symbols.isEmpty {
            let symbolsParam = symbols.joined(separator: ",")
            urlString += "?symbols=\(symbolsParam)"
        }

        guard let url = URL(string: urlString) else {
            throw BackendPriceError.invalidURL
        }

        // Create request
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Execute request
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendPriceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw BackendPriceError.httpError(statusCode: httpResponse.statusCode)
        }

        // Decode response
        let pricesResponse = try decoder.decode(PricesLatestResponse.self, from: data)

        // Convert to BackendPrice and update cache
        let now = Date()
        var results: [BackendPrice] = []

        for item in pricesResponse.prices {
            guard let price = item.price, price > 0 else { continue }

            let updatedAt = parseDate(item.updatedAt ?? "")

            // Apply 1/x inversion for forex (fx) prices
            // This converts from "1 USD = X currency" to "1 currency = X USD"
            let adjustedPrice: Decimal
            if item.assetClass.lowercased() == "fx" {
                adjustedPrice = Decimal(1.0 / price)
            } else {
                adjustedPrice = Decimal(price)
            }

            let backendPrice = BackendPrice(
                assetCode: item.symbol,
                displayName: item.displayName,
                assetClass: item.assetClass,
                price: adjustedPrice,
                change24h: item.percentChange24h,
                currency: item.currency,
                updatedAt: updatedAt
            )

            // Update cache
            priceCache[item.symbol] = (backendPrice, now)
            results.append(backendPrice)
        }

        print("✅ Loaded \(results.count) prices from backend")
        return results
    }

    /// Fetch single price
    func fetchPrice(for symbol: String) async throws -> BackendPrice? {
        // Check cache first
        let now = Date()
        if let cached = priceCache[symbol], now.timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.price
        }

        let prices = try await fetchPrices(symbols: [symbol])
        return prices.first
    }

    // MARK: - Historical Prices

    /// Fetch historical OHLCV data
    func fetchHistoricalPrices(for symbol: String, range: String = "1m") async throws -> [OHLCVItem]
    {
        let urlString = "\(baseURL)/prices-history?symbol=\(symbol)&range=\(range)"

        guard let url = URL(string: urlString) else {
            throw BackendPriceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw BackendPriceError.invalidResponse
        }

        let historyResponse = try decoder.decode(PricesHistoryResponse.self, from: data)
        return historyResponse.data
    }

    // MARK: - Cache Helpers

    private func getCachedPrices(for symbols: [String]) -> [BackendPrice] {
        let now = Date()
        return symbols.compactMap { symbol in
            guard let cached = priceCache[symbol],
                now.timeIntervalSince(cached.timestamp) < cacheTTL
            else {
                return nil
            }
            return cached.price
        }
    }

    /// Clear all cached prices
    func clearCache() {
        priceCache.removeAll()
    }

    // MARK: - Helpers

    private func parseDate(_ dateString: String) -> Date {
        // Try ISO8601 format first
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }

        // Try without fractional seconds
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }

        // Try simple date format
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            return date
        }

        return Date()
    }
}

// MARK: - Errors
enum BackendPriceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case apiError(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}
