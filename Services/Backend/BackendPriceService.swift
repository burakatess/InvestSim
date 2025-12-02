// Services/Backend/BackendPriceService.swift
import Foundation

// MARK: - Response Models
struct BackendPriceResponse: Codable {
    let success: Bool
    let count: Int
    let data: [BackendPrice]
    let timestamp: String
}

struct BackendPrice: Codable {
    let assetCode: String
    let price: Decimal
    let change24h: Double?
    let volume24h: Decimal?
    let marketCap: Decimal?
    let category: String
    let provider: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case assetCode = "asset_code"
        case price
        case change24h = "change_24h"
        case volume24h = "volume_24h"
        case marketCap = "market_cap"
        case category
        case provider
        case updatedAt = "updated_at"
    }
}

// MARK: - Backend Price Service
@MainActor
class BackendPriceService {
    static let shared = BackendPriceService()

    // Supabase Configuration
    private let baseURL: String
    private let apiKey: String

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        // Load from environment or config
        // TODO: User will replace these with their actual values
        self.baseURL =
            ProcessInfo.processInfo.environment["SUPABASE_URL"]
            ?? "https://hplmwcjyfzjghijdqypa.supabase.co/functions/v1"
        self.apiKey =
            ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
            ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwbG13Y2p5ZnpqZ2hpamRxeXBhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjY1NjEsImV4cCI6MjA3OTIwMjU2MX0.G5Cv2az01Jis-fH4P7ThakjQfVfGI8UMKwrY-hTh5k4"

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Fetch Prices
    /// Fetch historical price data for a specific asset within a date range
    /// - Parameters:
    ///   - code: Asset code string
    ///   - start: Start date (inclusive)
    ///   - end: End date (inclusive)
    /// - Returns: Array of `BackendPrice` representing historical entries
    func fetchHistoricalPrices(for code: String, start: Date, end: Date) async throws
        -> [BackendPrice]
    {
        var components = URLComponents(string: "\(baseURL)/get-historical-prices")!
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let startStr = isoFormatter.string(from: start)
        let endStr = isoFormatter.string(from: end)
        components.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "start", value: startStr),
            URLQueryItem(name: "end", value: endStr),
        ]
        guard let url = components.url else { throw BackendError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw BackendError.httpError(statusCode: httpResponse.statusCode)
        }
        let priceResponse = try decoder.decode(BackendPriceResponse.self, from: data)
        guard priceResponse.success else {
            throw BackendError.apiError(message: "API returned success: false")
        }
        return priceResponse.data
    }

    /// Fetch all prices or filter by category
    func fetchPrices(category: String? = nil, limit: Int = 100) async throws -> [BackendPrice] {
        var components = URLComponents(string: "\(baseURL)/get-prices")!
        var queryItems: [URLQueryItem] = []

        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))

        components.queryItems = queryItems

        guard let url = components.url else {
            throw BackendError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw BackendError.httpError(statusCode: httpResponse.statusCode)
        }

        let priceResponse = try decoder.decode(BackendPriceResponse.self, from: data)

        guard priceResponse.success else {
            throw BackendError.apiError(message: "API returned success: false")
        }

        return priceResponse.data
    }

    /// Fetch specific asset prices by codes
    func fetchPrices(for codes: [String]) async throws -> [BackendPrice] {
        guard !codes.isEmpty else { return [] }

        var components = URLComponents(string: "\(baseURL)/get-prices")!
        components.queryItems = [
            URLQueryItem(name: "codes", value: codes.joined(separator: ","))
        ]

        guard let url = components.url else {
            throw BackendError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw BackendError.httpError(statusCode: httpResponse.statusCode)
        }

        let priceResponse = try decoder.decode(BackendPriceResponse.self, from: data)
        return priceResponse.data
    }

    /// Fetch single asset price
    func fetchPrice(for code: String) async throws -> BackendPrice? {
        let prices = try await fetchPrices(for: [code])
        return prices.first
    }
}

// MARK: - Errors
enum BackendError: LocalizedError {
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

// MARK: - Test (Temporary)
extension BackendPriceService {
    func testConnection() async {
        print("🔄 Testing backend connection...")
        print("📡 URL: \(baseURL)")

        do {
            let prices = try await fetchPrices(limit: 10)
            print("✅ Backend connection successful!")
            print("📊 Fetched \(prices.count) prices:")
            for price in prices {
                print("  - \(price.assetCode): $\(price.price) (\(price.category))")
            }
        } catch {
            print("❌ Backend connection failed: \(error)")
            if let backendError = error as? BackendError {
                print("   Error type: \(backendError.errorDescription ?? "Unknown")")
            }
        }
    }
}
