import Combine
import CoreData
import Foundation

class DCAScheduler: ObservableObject {
    @Published var trades: [DCATrade] = []
    @Published var isLoading = false
    @Published var error: String?

    private let calendar = Calendar.current
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func generateTrades(for plan: DCAPlan, from startDate: Date, to endDate: Date) {
        isLoading = true
        error = nil

        var generatedTrades: [DCATrade] = []
        var currentDate = startDate

        while currentDate <= endDate {
            if shouldExecuteTrade(on: currentDate, for: plan) {
                let assetCode = AssetCode(plan.asset ?? plan.assetCode ?? "USD")
                let price = getPrice(for: assetCode, on: currentDate)
                let amount = plan.amountTRY?.decimalValue ?? 0

                let trade = DCATrade(context: context)
                trade.id = UUID()
                trade.planId = plan.id
                trade.asset = assetCode.rawValue
                trade.tradeDate = currentDate
                trade.unitPriceTRY = NSDecimalNumber(decimal: price)
                trade.quantity = NSDecimalNumber(decimal: amount / max(price, Decimal(0.0001)))
                trade.totalCostTRY = NSDecimalNumber(decimal: amount)
                trade.source = TradeSource.dca.rawValue
                trade.createdAt = Date()
                generatedTrades.append(trade)
            }

            currentDate = getNextExecutionDate(from: currentDate, for: plan)
        }

        DispatchQueue.main.async {
            self.trades = generatedTrades
            self.isLoading = false
        }
    }

    private func shouldExecuteTrade(on date: Date, for plan: DCAPlan) -> Bool {
        if calendar.isDateInWeekend(date) {
            return false
        }

        if let frequency = plan.frequency {
            switch frequency {
            case "monthly":
                return calendar.component(.day, from: date) == Int(plan.dayOfMonth)
            case "weekly":
                return calendar.component(.weekday, from: date) == Int(plan.dayOfWeek)
            default:
                break
            }
        }

        return false
    }

    private func getNextExecutionDate(from date: Date, for plan: DCAPlan) -> Date {
        if let frequency = plan.frequency {
            switch frequency {
            case "monthly":
                return calendar.date(byAdding: .month, value: 1, to: date) ?? date
            case "weekly":
                return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
            default:
                return date
            }
        }
        return date
    }

    private func getPrice(for asset: AssetCode, on date: Date) -> Decimal {
        // Mock prices for all assets
        switch asset {
        // Döviz
        case .USD: return 34.25
        case .EUR: return 37.10
        case .GBP: return 43.75
        case .JPY: return 0.25
        case .AUD: return 22.50
        case .CAD: return 25.40
        case .CHF: return 38.20
        case .CNH: return 4.80
        case .HKD: return 4.50
        case .NZD: return 20.75

        // Kripto Paralar - Mock prices (USDT cinsinden)
        case .BTC: return 45000.0
        case .ETH: return 3200.0
        case .BNB: return 320.0
        case .XRP: return 0.65
        case .ADA: return 0.45
        case .DOGE: return 0.08
        case .SOL: return 95.0
        case .MATIC: return 0.85
        case .DOT: return 6.50
        case .AVAX: return 25.0
        case .LTC: return 75.0
        case .UNI: return 8.50
        case .LINK: return 12.0
        case .ATOM: return 8.75
        case .ETC: return 18.0
        case .XLM: return 0.12
        case .ALGO: return 0.15
        case .VET: return 0.025
        case .ICP: return 4.20
        case .FIL: return 3.50
        default:
            return 10.0
        }
    }
}
