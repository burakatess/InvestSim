import Combine
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

// MARK: - WebSocket Errors
public enum WebSocketError: Error {
    case invalidURL
    case connectionFailed
    case authenticationFailed
    case subscriptionFailed
    case parseError
    case timeout
}

// MARK: - WebSocket Provider Protocol
public protocol WebSocketProvider: AnyObject {
    var priceUpdatePublisher: PassthroughSubject<PriceUpdate, Never> { get }
    var connectionStatePublisher: PassthroughSubject<ConnectionState, Never> { get }

    func connect()
    func disconnect()
    func subscribe(symbols: [String])
    func unsubscribe(symbols: [String])
}
