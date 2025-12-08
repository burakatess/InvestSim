import Foundation
import Supabase

/// Service to fetch historical prices from Supabase for DCA simulations
/// Uses prices_history table (main historical data source with 49K+ records)
final class SupabaseHistoricalPriceService: @unchecked Sendable {
    static let shared = SupabaseHistoricalPriceService()

    private let supabase: SupabaseClient

    private init() {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://hplmwcjyfzjghijdqypa.supabase.co")!,
            supabaseKey:
                "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwbG13Y2p5ZnpqZ2hpamRxeXBhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjY1NjEsImV4cCI6MjA3OTIwMjU2MX0.G5Cv2az01Jis-fH4P7ThakjQfVfGI8UMKwrY-hTh5k4"
        )
    }

    /// Fetch all historical prices for multiple assets in a date range
    /// Uses prices_history table (main source) with fallback to price_history
    /// Returns: [AssetCode: [Date: Price]]
    func fetchPrices(
        assetCodes: [String],
        startDate: Date,
        endDate: Date
    ) async throws -> [String: [Date: Decimal]] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let startString = dateFormatter.string(from: startDate)
        let endString = dateFormatter.string(from: endDate)

        var results: [String: [Date: Decimal]] = [:]

        // First get asset IDs for the symbols
        let assetsResponse: [SimpleAssetRecord] =
            try await supabase
            .from("assets")
            .select("id, symbol")
            .in("symbol", values: assetCodes)
            .execute()
            .value

        let symbolToId: [String: String] = Dictionary(
            uniqueKeysWithValues: assetsResponse.map { ($0.symbol, $0.id) }
        )

        // Fetch prices for each asset
        for assetCode in assetCodes {
            guard let assetId = symbolToId[assetCode] else {
                results[assetCode] = [:]
                continue
            }

            var priceMap: [Date: Decimal] = [:]

            // Try prices_history first (main table with 49K+ records)
            let pricesHistoryResponse: [SimplePriceRecord] =
                try await supabase
                .from("prices_history")
                .select("date, close")
                .eq("asset_id", value: assetId)
                .gte("date", value: startString)
                .lte("date", value: endString)
                .order("date", ascending: true)
                .execute()
                .value

            for record in pricesHistoryResponse {
                if let date = dateFormatter.date(from: record.dateString),
                    let closePrice = record.close
                {
                    priceMap[date] = Decimal(closePrice)
                }
            }

            // If no data found, try price_history (secondary table)
            if priceMap.isEmpty {
                let priceHistoryResponse: [SimplePriceRecord] =
                    try await supabase
                    .from("price_history")
                    .select("date, close")
                    .eq("asset_id", value: assetId)
                    .gte("date", value: startString)
                    .lte("date", value: endString)
                    .order("date", ascending: true)
                    .execute()
                    .value

                for record in priceHistoryResponse {
                    if let date = dateFormatter.date(from: record.dateString),
                        let closePrice = record.close
                    {
                        priceMap[date] = Decimal(closePrice)
                    }
                }
            }

            results[assetCode] = priceMap
        }

        return results
    }

    /// Get closest available price for a date (looking backwards up to 7 days)
    func getClosestPrice(assetCode: String, targetDate: Date, priceCache: [Date: Decimal])
        -> Decimal?
    {
        let calendar = Calendar.current

        // Try exact date
        let startOfDay = calendar.startOfDay(for: targetDate)
        if let price = priceCache[startOfDay] {
            return price
        }

        // Look backwards up to 7 days (for weekends/holidays)
        for daysBack in 1...7 {
            if let previousDate = calendar.date(byAdding: .day, value: -daysBack, to: startOfDay),
                let price = priceCache[previousDate]
            {
                return price
            }
        }

        return nil
    }
}

// MARK: - Response Models (unique names to avoid conflicts)
private struct SimpleAssetRecord: Codable {
    let id: String
    let symbol: String
}

private struct SimplePriceRecord: Codable {
    let close: Double?
    let dateString: String

    enum CodingKeys: String, CodingKey {
        case close
        case dateString = "date"
    }
}
