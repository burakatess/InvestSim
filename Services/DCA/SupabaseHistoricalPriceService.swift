import Foundation
import Supabase

/// Service to fetch historical prices from Supabase for DCA simulations
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

    /// Fetch historical price for a specific asset on a specific date
    /// Falls back to nearest available date if exact date not found
    func fetchPrice(assetCode: String, date: Date) async throws -> Decimal? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        // Try exact date first
        let response: [HistoricalPriceRecord] =
            try await supabase
            .from("historical_prices")
            .select("close, date")
            .eq("asset_code", value: assetCode)
            .lte("date", value: dateString)
            .order("date", ascending: false)
            .limit(1)
            .execute()
            .value

        if let record = response.first {
            return record.close
        }

        return nil
    }

    /// Fetch all historical prices for multiple assets in a date range
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

        // Fetch prices for each asset
        for assetCode in assetCodes {
            let response: [HistoricalPriceRecord] =
                try await supabase
                .from("historical_prices")
                .select("date, close")
                .eq("asset_code", value: assetCode)
                .gte("date", value: startString)
                .lte("date", value: endString)
                .order("date", ascending: true)
                .execute()
                .value

            var priceMap: [Date: Decimal] = [:]
            for record in response {
                if let date = dateFormatter.date(from: record.dateString) {
                    priceMap[date] = record.close
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

// MARK: - Historical Price Record (Supabase Response)
private struct HistoricalPriceRecord: Codable {
    let close: Decimal
    let dateString: String

    enum CodingKeys: String, CodingKey {
        case close
        case dateString = "date"
    }
}
