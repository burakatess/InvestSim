// Services/Backend/BackendPriceService.swift
import Foundation
import Supabase

// MARK: - Response Models

struct BatchPriceResponse: Codable {
    let prices: [BatchPriceItem]
    let cached: Int
    let fetched: Int
    let total: Int
}

struct BatchPriceItem: Codable {
    let symbol: String
    let price: Double
    let change24h: Double?
    let updatedAt: String
    let source: String
}

struct HistoryResponse: Codable {
    let symbol: String
    let range: String
    let data: [OHLCVItem]
    let count: Int
}

struct OHLCVItem: Codable {
    let date: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double?
}

// MARK: - Internal Model (Adapter)
struct BackendPrice: Codable {
    let assetCode: String
    let price: Decimal
    let change24h: Double?
    let volume24h: Decimal?
    let marketCap: Decimal?
    let category: String?
    let provider: String?
    let updatedAt: Date
}

// MARK: - Latest Price from DB
struct LatestPriceRow: Codable {
    let assetId: UUID
    let price: Double
    let percentChange24h: Double?
    let provider: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case price
        case percentChange24h = "percent_change_24h"
        case provider
        case updatedAt = "updated_at"
    }
}

// MARK: - Asset ID Row for join queries
struct AssetIdRow: Codable {
    let id: UUID
    let code: String
}

// MARK: - Backend Price Service
@MainActor
class BackendPriceService {
    static let shared = BackendPriceService()

    // Supabase Configuration
    private let functionsBaseURL: String
    private let apiKey: String
    private let supabase: SupabaseClient

    private let session: URLSession
    private let decoder: JSONDecoder

    // Debounce flag to prevent concurrent fetch floods
    private var isFetching = false

    private init() {
        // Load from environment or config
        self.functionsBaseURL =
            ProcessInfo.processInfo.environment["SUPABASE_URL"]
            ?? "https://hplmwcjyfzjghijdqypa.supabase.co/functions/v1"
        self.apiKey =
            ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
            ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwbG13Y2p5ZnpqZ2hpamRxeXBhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjY1NjEsImV4cCI6MjA3OTIwMjU2MX0.G5Cv2az01Jis-fH4P7ThakjQfVfGI8UMKwrY-hTh5k4"

        // Initialize Supabase client for direct DB access
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://hplmwcjyfzjghijdqypa.supabase.co")!,
            supabaseKey: apiKey
        )

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45  // Increased timeout for larger batches
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        // Backend returns ISO8601 strings
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Fetch Prices

    /// Fetch prices - first try latest_prices table (fast), then fallback to Edge Function
    func fetchPrices(for codes: [String]) async throws -> [BackendPrice] {
        guard !codes.isEmpty else { return [] }

        // Prevent concurrent fetches - if already fetching, skip
        guard !isFetching else {
            print("⏸️ Skipping fetch - already in progress")
            return []
        }

        isFetching = true
        defer { isFetching = false }

        // STEP 1: Try direct database read (super fast ~200ms)
        var allPrices: [BackendPrice] = []
        var missingCodes: [String] = []

        do {
            let dbPrices = try await fetchFromDatabase(codes: codes)
            allPrices.append(contentsOf: dbPrices)

            // Find which codes are missing from DB
            let foundCodes = Set(dbPrices.map { $0.assetCode })
            missingCodes = codes.filter { !foundCodes.contains($0) }

            if !dbPrices.isEmpty {
                print("⚡ Loaded \(dbPrices.count) prices from database (fast path)")
            }
        } catch {
            print("⚠️ Database read failed: \(error.localizedDescription)")
            missingCodes = codes  // Fallback to fetch all from Edge Function
        }

        // STEP 2: Fetch missing prices from Edge Function
        if !missingCodes.isEmpty {
            print("🔄 Fetching \(missingCodes.count) missing prices from Edge Function...")

            // Chunk into batches of 25
            let batchSize = 25
            let chunks = missingCodes.chunked(into: batchSize)

            for (index, chunk) in chunks.enumerated() {
                do {
                    let prices = try await fetchSingleBatch(codes: chunk)
                    allPrices.append(contentsOf: prices)

                    // Short delay between batches
                    if index < chunks.count - 1 {
                        try await Task.sleep(nanoseconds: 300_000_000)
                    }
                } catch {
                    print("⚠️ Batch \(index + 1) failed: \(error.localizedDescription)")
                }
            }
        }

        print("📊 Total: \(allPrices.count) prices loaded")
        return allPrices
    }

    /// Fast path: Read prices directly from latest_prices table
    private func fetchFromDatabase(codes: [String]) async throws -> [BackendPrice] {
        // First get asset IDs for the codes
        let assets: [AssetIdRow] =
            try await supabase
            .from("assets")
            .select("id, code")
            .in("code", values: codes)
            .execute()
            .value

        guard !assets.isEmpty else { return [] }

        let assetIds = assets.map { $0.id.uuidString }
        let codeMap: [UUID: String] = Dictionary(
            uniqueKeysWithValues: assets.map { ($0.id, $0.code) })

        // Get prices from latest_prices
        let prices: [LatestPriceRow] =
            try await supabase
            .from("latest_prices")
            .select("asset_id, price, percent_change_24h, provider, updated_at")
            .in("asset_id", values: assetIds)
            .execute()
            .value

        // Convert to BackendPrice
        return prices.compactMap { row -> BackendPrice? in
            guard let code = codeMap[row.assetId] else { return nil }
            return BackendPrice(
                assetCode: code,
                price: Decimal(row.price),
                change24h: row.percentChange24h,
                volume24h: nil,
                marketCap: nil,
                category: nil,
                provider: row.provider,
                updatedAt: row.updatedAt
            )
        }
    }

    /// Fetch a single batch of prices
    private func fetchSingleBatch(codes: [String]) async throws -> [BackendPrice] {
        let url = URL(string: "\(functionsBaseURL)/get-batch-prices")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["symbols": codes]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendPriceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw BackendPriceError.httpError(statusCode: httpResponse.statusCode)
        }

        let batchResponse = try decoder.decode(BatchPriceResponse.self, from: data)

        // Map to BackendPrice
        return batchResponse.prices.map { item in
            let date = ISO8601DateFormatter().date(from: item.updatedAt) ?? Date()
            return BackendPrice(
                assetCode: item.symbol,
                price: Decimal(item.price),
                change24h: item.change24h,
                volume24h: nil,
                marketCap: nil,
                category: nil,
                provider: item.source,
                updatedAt: date
            )
        }
    }

    /// Fetch historical price data using get-history (GET)
    func fetchHistoricalPrices(for code: String, start: Date, end: Date) async throws
        -> [BackendPrice]
    {
        // Note: The backend get-history endpoint currently takes 'range' (e.g. 1d, 1m) rather than start/end dates.
        // For MVP, we'll map the duration between start/end to the closest range.
        let range = calculateRange(start: start, end: end)

        var components = URLComponents(string: "\(functionsBaseURL)/get-history")!
        components.queryItems = [
            URLQueryItem(name: "symbol", value: code),
            URLQueryItem(name: "range", value: range),
        ]

        guard let url = components.url else { throw BackendPriceError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendPriceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw BackendPriceError.httpError(statusCode: httpResponse.statusCode)
        }

        let historyResponse = try decoder.decode(HistoryResponse.self, from: data)

        // Map OHLCV to BackendPrice (using close price)
        return historyResponse.data.map { item in
            // Backend returns date as YYYY-MM-DD or similar, need to parse
            // The backend uses ISO string in some places, but let's check get-history implementation
            // get-history returns data from price_history tables where date is YYYY-MM-DD
            let date = self.parseDate(item.date)
            return BackendPrice(
                assetCode: code,
                price: Decimal(item.close),
                change24h: nil,
                volume24h: item.volume != nil ? Decimal(item.volume!) : nil,
                marketCap: nil,
                category: nil,
                provider: "history",
                updatedAt: date
            )
        }
    }

    /// Fetch single asset price
    func fetchPrice(for code: String) async throws -> BackendPrice? {
        let prices = try await fetchPrices(for: [code])
        return prices.first
    }

    // MARK: - Helpers

    private func calculateRange(start: Date, end: Date) -> String {
        let diff = end.timeIntervalSince(start)
        let days = diff / 86400

        if days <= 1 { return "1d" }
        if days <= 7 { return "7d" }
        if days <= 30 { return "1m" }
        if days <= 90 { return "3m" }
        if days <= 180 { return "6m" }
        if days <= 365 { return "1y" }
        return "all"
    }

    private func parseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            return date
        }
        return ISO8601DateFormatter().date(from: dateString) ?? Date()
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
