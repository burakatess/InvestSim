import Combine
import Foundation

/// Alpha Vantage Provider for Forex & Commodity historical data
/// Free tier: 25 requests/day, unlimited historical data
final class AlphaVantageProvider {
    // MARK: - Properties
    private let apiKey: String
    private let baseURL = "https://www.alphavantage.co/query"

    // MARK: - Initialization
    init(apiKey: String = "YOUR_ALPHA_VANTAGE_API_KEY") {
        self.apiKey = apiKey
        print("📊 AlphaVantageProvider initialized")
    }

    // MARK: - Forex Historical Data
    /// Fetch historical forex data
    /// - Parameters:
    ///   - fromCurrency: Base currency (e.g. "EUR")
    ///   - toCurrency: Quote currency (e.g. "USD")
    ///   - startDate: Start date for historical data
    ///   - endDate: End date for historical data
    ///   - completion: Completion handler with array of historical prices
    func fetchForexHistoricalData(
        fromCurrency: String,
        toCurrency: String,
        startDate: Date,
        endDate: Date,
        completion: @escaping (Result<[AlphaVantageHistoricalPrice], Error>) -> Void
    ) {
        // Alpha Vantage FX_DAILY endpoint
        let urlString =
            "\(baseURL)?function=FX_DAILY&from_symbol=\(fromCurrency)&to_symbol=\(toCurrency)&outputsize=full&apikey=\(apiKey)"

        guard let url = URL(string: urlString) else {
            completion(
                .failure(
                    NSError(
                        domain: "AlphaVantage", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
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
                            domain: "AlphaVantage", code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let response = try JSONDecoder().decode(AlphaVantageForexResponse.self, from: data)

                // Check for error message
                if let errorMessage = response.errorMessage {
                    completion(
                        .failure(
                            NSError(
                                domain: "AlphaVantage", code: -3,
                                userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                    return
                }

                guard let timeSeries = response.timeSeries else {
                    completion(
                        .failure(
                            NSError(
                                domain: "AlphaVantage", code: -4,
                                userInfo: [NSLocalizedDescriptionKey: "No time series data"])))
                    return
                }

                // Parse and filter by date range
                var historicalPrices: [AlphaVantageHistoricalPrice] = []
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"

                for (dateString, priceData) in timeSeries {
                    if let date = dateFormatter.date(from: dateString),
                        date >= startDate && date <= endDate,
                        let closeString = priceData["4. close"],
                        let close = Double(closeString)
                    {
                        let price = AlphaVantageHistoricalPrice(date: date, close: close)
                        historicalPrices.append(price)
                    }
                }

                // Sort by date (oldest first)
                historicalPrices.sort { $0.date < $1.date }

                completion(.success(historicalPrices))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Commodity Historical Data
    /// Fetch historical commodity data
    /// - Parameters:
    ///   - commodity: Commodity symbol (e.g. "XAU" for Gold, "XAG" for Silver)
    ///   - startDate: Start date for historical data
    ///   - endDate: End date for historical data
    ///   - completion: Completion handler with array of historical prices
    func fetchCommodityHistoricalData(
        commodity: String,
        startDate: Date,
        endDate: Date,
        completion: @escaping (Result<[AlphaVantageHistoricalPrice], Error>) -> Void
    ) {
        // For commodities, we use the same FX endpoint with USD as quote currency
        // XAU/USD for Gold, XAG/USD for Silver, etc.
        fetchForexHistoricalData(
            fromCurrency: commodity,
            toCurrency: "USD",
            startDate: startDate,
            endDate: endDate,
            completion: completion
        )
    }
}

// MARK: - Models
private struct AlphaVantageForexResponse: Codable {
    let metaData: MetaData?
    let timeSeries: [String: [String: String]]?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case metaData = "Meta Data"
        case timeSeries = "Time Series FX (Daily)"
        case errorMessage = "Error Message"
    }

    struct MetaData: Codable {
        let information: String
        let fromSymbol: String
        let toSymbol: String

        enum CodingKeys: String, CodingKey {
            case information = "1. Information"
            case fromSymbol = "2. From Symbol"
            case toSymbol = "3. To Symbol"
        }
    }
}

struct AlphaVantageHistoricalPrice {
    let date: Date
    let close: Double
}
