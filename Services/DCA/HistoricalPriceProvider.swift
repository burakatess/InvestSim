import Foundation

struct HistoricalPriceProvider: DCAProvider {
    private let history: [String: [Date: Decimal]]
    private let latest: [String: Decimal]
    private let calendar = Calendar(identifier: .gregorian)

    init(history: [String: [Date: Decimal]], latest: [String: Decimal]) {
        self.history = history
        self.latest = latest
    }

    func historicalPrice(on date: Date, symbol: String) -> Decimal? {
        let key = calendar.startOfDay(for: date)
        return history[symbol]?[key]
    }

    func latestPrice(symbol: String) -> Decimal? {
        latest[symbol]
    }

    func priceHistory(symbol: String, from startDate: Date, to endDate: Date) -> [Date: Decimal] {
        guard let map = history[symbol] else { return [:] }
        var result: [Date: Decimal] = [:]
        var cursor = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        var last: Decimal?
        while cursor <= endDay {
            if let price = map[cursor] {
                last = price
                result[cursor] = price
            } else if let last {
                result[cursor] = last
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    func isSymbolAvailable(_ symbol: String) -> Bool {
        history[symbol] != nil
    }

    func availableSymbols() -> [String] {
        Array(history.keys)
    }
}
