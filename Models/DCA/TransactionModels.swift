import Foundation

struct AssetTransaction: Identifiable, Codable, Equatable {
    let id: UUID
    let assetCode: AssetCode
    let amountTRY: Decimal
    let percentage: Decimal
    let units: Decimal
    let unitPriceTRY: Decimal

    init(
        id: UUID = UUID(),
        assetCode: AssetCode,
        amountTRY: Decimal,
        percentage: Decimal,
        units: Decimal = 0,
        unitPriceTRY: Decimal = 0
    ) {
        self.id = id
        self.assetCode = assetCode
        self.amountTRY = amountTRY
        self.percentage = percentage
        self.units = units
        self.unitPriceTRY = unitPriceTRY
    }

    var assetSymbol: String { assetCode.symbol }
}

enum TransactionType: String, Codable {
    case initial = "Başlangıç Yatırımı"
    case monthly = "Aylık Yatırım"
}

struct Transaction: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let totalAmount: Decimal
    let distribution: [AssetTransaction]
    let type: TransactionType

    init(
        id: UUID = UUID(),
        date: Date,
        totalAmount: Decimal,
        distribution: [AssetTransaction],
        type: TransactionType
    ) {
        self.id = id
        self.date = date
        self.totalAmount = totalAmount
        self.distribution = distribution
        self.type = type
    }
}
