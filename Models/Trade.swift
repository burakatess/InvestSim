import Foundation

// MARK: - Simple Trade Model
struct Trade: Identifiable, Codable {
    var id = UUID()
    let asset: AssetCode
    let quantity: Double
    let price: Double
    let type: TradeType
    let date: Date

    enum TradeType: Codable {
        case buy, sell
    }
}
