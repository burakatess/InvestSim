import Foundation

struct PricePoint: Identifiable, Codable, Equatable {
    var id = UUID()
    let date: Date
    let price: Decimal
    let currency: String
    let priceTRY: Decimal

    init(date: Date, price: Decimal, currency: String = "USD") {
        self.date = date
        self.price = price
        self.currency = currency
        self.priceTRY = price
    }
}

extension PricePoint {
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: price as NSDecimalNumber) ?? "$0.00"
    }
}
