import Combine
import Foundation

/// Service to fetch Yahoo Finance cookie and crumb for authentication
final class YahooCrumbService {
    static let shared = YahooCrumbService()

    private var cookie: String?
    private var crumb: String?
    private var isFetching = false

    private init() {}

    /// Get valid crumb and cookie, fetching if necessary
    func getCrumb(completion: @escaping (Result<(cookie: String, crumb: String), Error>) -> Void) {
        if let cookie = cookie, let crumb = crumb {
            completion(.success((cookie, crumb)))
            return
        }

        fetchCrumb(completion: completion)
    }

    private func fetchCrumb(
        completion: @escaping (Result<(cookie: String, crumb: String), Error>) -> Void
    ) {
        guard !isFetching else {
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.getCrumb(completion: completion)
            }
            return
        }

        isFetching = true

        // 1. Get Cookie from main page
        // fc.yahoo.com is often unreliable. finance.yahoo.com sets the necessary cookies (A3, etc.)
        let url = URL(string: "https://finance.yahoo.com")!
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self else { return }

            if let httpResponse = response as? HTTPURLResponse,
                let fields = httpResponse.allHeaderFields as? [String: String],
                let url = response?.url
            {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)

                // We need to store ALL cookies, not just A3, as they might be interdependent
                // But usually A3 is the key one. Let's try to construct a full cookie string.
                let cookieString = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")

                if !cookieString.isEmpty {
                    self.cookie = cookieString
                    self.fetchCrumbValue(cookie: cookieString, completion: completion)
                    return
                }
            }

            // Fallback: Try fetching crumb without cookie (sometimes works or sets cookie in response)
            self.fetchCrumbValue(cookie: "", completion: completion)

        }.resume()
    }

    private func fetchCrumbValue(
        cookie: String,
        completion: @escaping (Result<(cookie: String, crumb: String), Error>) -> Void
    ) {
        let url = URL(string: "https://query1.finance.yahoo.com/v1/test/getcrumb")!
        var request = URLRequest(url: url)
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            self.isFetching = false

            if let data = data, let crumb = String(data: data, encoding: .utf8), !crumb.isEmpty {
                // Validate that crumb is not an error JSON
                if crumb.contains("{") || crumb.contains("error") {
                    print("❌ Yahoo Crumb returned error JSON: \(crumb)")
                    completion(
                        .failure(
                            NSError(
                                domain: "YahooCrumb", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Invalid crumb response"])))
                    return
                }

                self.crumb = crumb
                self.cookie = cookie
                print("🍪 Yahoo Crumb fetched: \(crumb)")
                completion(.success((cookie, crumb)))
            } else {
                print("❌ Failed to fetch Yahoo Crumb")
                completion(
                    .failure(
                        NSError(
                            domain: "YahooCrumb", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to get crumb"])))
            }
        }.resume()
    }
}

final class YahooFinanceProvider: SubscribableProvider {
    // MARK: - Properties
    private let baseURL = "https://query1.finance.yahoo.com/v7/finance/quote"
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // State
    private var subscribedSymbols: Set<String> = []
    private var isPolling = false

    // Publishers
    let priceUpdatePublisher = PassthroughSubject<PriceUpdate, Never>()
    let connectionStatePublisher = PassthroughSubject<ConnectionState, Never>()

    // SubscribableProvider conformance
    var isConnected: Bool {
        isPolling
    }

    // MARK: - Initialization
    init() {
        print("📈 YahooFinanceProvider initialized")
    }

    deinit {
        stopPolling()
        print("📈 YahooFinanceProvider deinitialized")
    }

    // MARK: - Polling Management
    private func startPolling() {
        guard !isPolling else { return }

        isPolling = true
        connectionStatePublisher.send(.connected)

        // Initial fetch
        fetchNextBatch()

        // Poll with shorter interval for staggered batches
        // Instead of all at once every 15s, we fetch a small batch every 2s
        // This spreads the load and keeps RAM usage flat
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchNextBatch()
        }

        print("✅ Started Yahoo Finance Smart Polling (Staggered)")
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
        isPolling = false
        currentBatchIndex = 0
        connectionStatePublisher.send(.disconnected)
        print("❌ Stopped Yahoo Finance polling")
    }

    // MARK: - Price Fetching
    private var currentBatchIndex = 0
    private let batchSize = 20

    private func fetchNextBatch() {
        guard !subscribedSymbols.isEmpty else { return }

        let symbols = Array(subscribedSymbols)
        let totalSymbols = symbols.count

        // Calculate start and end indices for current batch
        let startIndex = currentBatchIndex % totalSymbols
        let endIndex = min(startIndex + batchSize, totalSymbols)

        let batch = Array(symbols[startIndex..<endIndex])

        // Fetch this batch
        fetchBatch(symbols: batch)

        // Update index for next timer tick
        currentBatchIndex += batchSize

        // If we looped around, we might want to wait a bit longer or just continue
        // With 2s interval and 20 items:
        // 100 items = 5 batches = 10 seconds to cycle through all.
        // This gives ~10-15s refresh rate per item, which is ideal.
        if currentBatchIndex >= totalSymbols {
            currentBatchIndex = 0
        }
    }

    private func fetchBatch(symbols: [String]) {
        // Use v8 chart endpoint which is more reliable and doesn't require crumb/cookie for public data
        // We can fetch multiple symbols by making parallel requests or using a different endpoint
        // v8 chart is per-symbol, so we need to iterate.
        // Alternatively, v7/finance/quote?symbols=... works WITHOUT crumb for many public assets if we don't send invalid cookies.
        // Let's try v7 quote WITHOUT crumb/cookie first, as it supports batching.

        performFetch(symbols: symbols)
    }

    private func performFetch(symbols: [String]) {
        let symbolsString = symbols.joined(separator: ",")

        // Try v7 quote without authentication first
        guard
            let url = URL(
                string: "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(symbolsString)"
            )
        else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent")

        // IMPORTANT: Do NOT send the "Cookie" header if we don't have a valid one,
        // as that triggers the "Invalid Cookie" error.

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if error != nil {
                return
            }

            guard let data = data else { return }

            // Check for error response
            if let errorResponse = try? JSONDecoder().decode(YahooErrorResponse.self, from: data),
                errorResponse.quoteResponse.error != nil
            {
                // If v7 fails, fallback to v8 chart for each symbol (slower but reliable)
                self.fetchViaChartAPI(symbols: symbols)
            } else {
                // Try to parse. If parsing fails, also fallback.
                if !self.parseQuoteResponse(data) {
                    print("⚠️ Yahoo v7 parsing failed, falling back to v8 Chart API")
                    self.fetchViaChartAPI(symbols: symbols)
                }
            }
        }
        task.resume()
    }

    private func fetchViaChartAPI(symbols: [String]) {
        for symbol in symbols {
            let urlString =
                "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d"
            guard let url = URL(string: urlString) else { continue }

            var request = URLRequest(url: url)
            request.setValue(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
                forHTTPHeaderField: "User-Agent")

            URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
                guard let self = self, let data = data else { return }
                self.parseChartResponse(data)
            }.resume()
        }
    }

    @discardableResult
    private func parseQuoteResponse(_ data: Data) -> Bool {
        do {
            let response = try JSONDecoder().decode(YahooQuoteResponse.self, from: data)

            if let result = response.quoteResponse.result {
                for quote in result {
                    let update = PriceUpdate(
                        assetCode: quote.symbol,
                        price: quote.regularMarketPrice,
                        source: "yahoo",
                        volume: Double(quote.regularMarketVolume ?? 0)
                    )

                    DispatchQueue.main.async {
                        self.priceUpdatePublisher.send(update)
                    }
                }
                return true
            }
            return false
        } catch {
            // Try parsing error
            if let errorResponse = try? JSONDecoder().decode(YahooErrorResponse.self, from: data) {
                print(
                    "❌ Yahoo API Error: \(errorResponse.quoteResponse.error?.description ?? "Unknown")"
                )
            } else {
                print("❌ Failed to parse Yahoo Quote response: \(error)")
            }
            return false
        }
    }

    private func parseChartResponse(_ data: Data) {
        do {
            let response = try JSONDecoder().decode(YahooChartResponse.self, from: data)

            if let result = response.chart.result {
                for quote in result {
                    if let meta = quote.meta, let price = meta.regularMarketPrice {
                        let update = PriceUpdate(
                            assetCode: meta.symbol,
                            price: price,
                            source: "yahoo",
                            volume: nil  // Volume not always available in meta
                        )

                        DispatchQueue.main.async {
                            self.priceUpdatePublisher.send(update)
                        }
                    }
                }
            } else if let error = response.chart.error {
                print("❌ Yahoo API Error: \(error.description ?? "Unknown error")")
            }
        } catch {
            if let rawString = String(data: data, encoding: .utf8) {
                print("❌ Failed to parse Yahoo response. Raw data: \(rawString)")
            } else {
                print("❌ Failed to parse Yahoo response: \(error)")
            }
        }
    }

    // MARK: - Historical Data Fetching
    /// Fetch historical price data for a symbol
    /// - Parameters:
    ///   - symbol: Stock symbol (e.g. "THYAO.IS")
    ///   - startDate: Start date for historical data
    ///   - endDate: End date for historical data
    ///   - completion: Completion handler with array of historical prices
    fileprivate func fetchHistoricalData(
        symbol: String,
        startDate: Date,
        endDate: Date,
        completion: @escaping (Result<[YahooHistoricalPrice], Error>) -> Void
    ) {
        let startTimestamp = Int(startDate.timeIntervalSince1970)
        let endTimestamp = Int(endDate.timeIntervalSince1970)

        // Use v8 chart endpoint which is more reliable than v7 quote
        let urlString =
            "https://query2.finance.yahoo.com/v8/finance/chart/\(symbol)?period1=\(startTimestamp)&period2=\(endTimestamp)&interval=1d"

        guard let url = URL(string: urlString) else {
            print("❌ Invalid Yahoo URL")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(
                    .failure(
                        NSError(
                            domain: "YahooFinance", code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let chartResponse = try JSONDecoder().decode(YahooChartResponse.self, from: data)

                if let result = chartResponse.chart.result?.first,
                    let timestamps = result.timestamp,
                    let quotes = result.indicators?.quote.first
                {
                    let closes = quotes.close
                    var historicalPrices: [YahooHistoricalPrice] = []

                    for (index, timestamp) in timestamps.enumerated() {
                        if index < closes.count, let close = closes[index] {
                            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                            let price = YahooHistoricalPrice(date: date, close: close)
                            historicalPrices.append(price)
                        }
                    }
                    completion(.success(historicalPrices))
                } else {
                    completion(
                        .failure(
                            NSError(
                                domain: "YahooFinance", code: -3,
                                userInfo: [NSLocalizedDescriptionKey: "Invalid response structure"])
                        ))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

// MARK: - WebSocketProvider Conformance
extension YahooFinanceProvider: WebSocketProvider {
    func connect() {
        // For polling provider, connect means ready to poll
        connectionStatePublisher.send(.connected)
    }

    func disconnect() {
        stopPolling()
    }

    func subscribe(symbols: [String]) {
        let newSymbols = Set(symbols)
        subscribedSymbols.formUnion(newSymbols)

        if !subscribedSymbols.isEmpty && !isPolling {
            startPolling()
        } else if isPolling {
            // If already polling, fetch new symbols immediately
            fetchBatch(symbols: symbols)
        }

        print("📈 Yahoo: Subscribed to \(symbols.count) symbols")
    }

    func unsubscribe(symbols: [String]) {
        subscribedSymbols.subtract(symbols)

        if subscribedSymbols.isEmpty {
            stopPolling()
        }
    }
}

// MARK: - Models

struct YahooHistoricalPrice {
    let date: Date
    let close: Double
}

private struct YahooChartResponse: Codable {
    let chart: ChartData
}

private struct ChartData: Codable {
    let result: [ChartResult]?
    let error: YahooError?
}

private struct YahooError: Codable {
    let code: String?
    let description: String?
}

private struct ChartResult: Codable {
    let meta: ChartMeta?
    let timestamp: [Int]?
    let indicators: Indicators?
}

private struct ChartMeta: Codable {
    let symbol: String
    let regularMarketPrice: Double?
    let previousClose: Double?
}

private struct Indicators: Codable {
    let quote: [Quote]
}

private struct Quote: Codable {
    let close: [Double?]
}

// MARK: - Quote Response Models (v7)
private struct YahooQuoteResponse: Codable {
    let quoteResponse: QuoteResponseData
}

private struct QuoteResponseData: Codable {
    let result: [YahooQuote]?
    let error: YahooError?
}

private struct YahooErrorResponse: Codable {
    let quoteResponse: QuoteResponseError
}

private struct QuoteResponseError: Codable {
    let error: YahooError?
}

private struct YahooQuote: Codable {
    let symbol: String
    let regularMarketPrice: Double
    let regularMarketVolume: Int64?
}

// MARK: - Array Extension
extension Array {
    fileprivate func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
