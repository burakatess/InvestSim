import Foundation

struct MoneyFormatter {
    static func format(_ amount: Decimal, decimals: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }

    static func formatTRY(_ amount: Decimal) -> String {
        return format(amount, decimals: 2)
    }

    static func formatUSD(_ amount: Decimal) -> String {
        return format(amount, decimals: 2)
    }

    static func formatNumber(_ number: Decimal, maxFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter.string(from: number as NSDecimalNumber) ?? "0"
    }

    static func formatPercentage(_ percentage: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: (percentage / 100) as NSDecimalNumber) ?? "0%"
    }
}
