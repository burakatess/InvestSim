import Foundation

// MARK: - Connection State
public enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error(Error)
}

// MARK: - Price Update
public struct PriceUpdate {
    public let assetCode: String
    public let price: Double
    public let source: String
    public let volume: Double?
    public let timestamp: Date

    public init(
        assetCode: String, price: Double, source: String, volume: Double? = nil,
        timestamp: Date = Date()
    ) {
        self.assetCode = assetCode
        self.price = price
        self.source = source
        self.volume = volume
        self.timestamp = timestamp
    }
}
