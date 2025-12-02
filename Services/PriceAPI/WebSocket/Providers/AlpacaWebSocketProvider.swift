import Combine
import Foundation

final class AlpacaWebSocketProvider: WebSocketProvider, SubscribableProvider {
    // MARK: - Properties
    private let baseURL = "wss://stream.data.alpaca.markets/v2/iex"
    private let apiKey: String
    private let apiSecret: String
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?

    private var subscribedSymbols: Set<String> = []
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var isAuthenticated = false

    // Publishers
    let priceUpdatePublisher = PassthroughSubject<PriceUpdate, Never>()
    let connectionStatePublisher = PassthroughSubject<ConnectionState, Never>()

    // SubscribableProvider conformance
    var isConnected: Bool {
        webSocket != nil && isAuthenticated
    }

    // MARK: - Initialization
    init(apiKey: String, apiSecret: String) {
        self.apiKey = apiKey
        self.apiSecret = apiSecret
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
        print("📈 AlpacaWebSocketProvider initialized")
    }

    deinit {
        disconnect()
        print("📈 AlpacaWebSocketProvider deinitialized")
    }

    // MARK: - Connection Management
    func connect() {
        guard webSocket == nil else {
            print("⚠️ Already connected to Alpaca")
            return
        }

        connectionStatePublisher.send(.connecting)

        guard let url = URL(string: baseURL) else {
            connectionStatePublisher.send(.error(WebSocketError.invalidURL))
            return
        }

        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()

        // Start receiving messages
        receiveMessage()

        // Authenticate
        authenticate()

        print("✅ Connected to Alpaca WebSocket")
    }

    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isAuthenticated = false

        connectionStatePublisher.send(.disconnected)
        print("❌ Disconnected from Alpaca WebSocket")
    }

    // MARK: - Authentication
    private func authenticate() {
        let authMessage: [String: Any] = [
            "action": "auth",
            "key": apiKey,
            "secret": apiSecret,
        ]

        sendMessage(authMessage)
        print("🔐 Authenticating with Alpaca...")
    }

    // MARK: - Subscription Management
    func subscribe(symbols: [String]) {
        subscribedSymbols.formUnion(symbols)

        guard webSocket != nil, isAuthenticated else {
            if webSocket == nil {
                connect()
            }
            return
        }

        // Alpaca free tier: max 30 symbols
        let limitedSymbols = Array(symbols.prefix(30))

        let message: [String: Any] = [
            "action": "subscribe",
            "trades": limitedSymbols,
        ]

        sendMessage(message)
        print("📡 Subscribed to \(limitedSymbols.count) Alpaca stocks")
    }

    func unsubscribe(symbols: [String]) {
        subscribedSymbols.subtract(symbols)

        let message: [String: Any] = [
            "action": "unsubscribe",
            "trades": symbols,
        ]

        sendMessage(message)
        print("📡 Unsubscribed from \(symbols.count) Alpaca stocks")
    }

    // MARK: - Message Handling
    private func sendMessage(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
            let jsonString = String(data: data, encoding: .utf8)
        else {
            return
        }

        webSocket?.send(.string(jsonString)) { error in
            if let error = error {
                print("❌ Failed to send message: \(error)")
            }
        }
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                // Continue receiving
                self.receiveMessage()

            case .failure(let error):
                print("❌ Alpaca WebSocket error: \(error)")
                self.connectionStatePublisher.send(.error(error))
                self.attemptReconnect()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseAlpacaMessage(text)

        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseAlpacaMessage(text)
            }

        @unknown default:
            print("⚠️ Unknown message type")
        }
    }

    private func parseAlpacaMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
            let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return
        }

        for json in jsonArray {
            guard let messageType = json["T"] as? String else {
                continue
            }

            switch messageType {
            case "success":
                if let msg = json["msg"] as? String {
                    if msg == "authenticated" {
                        isAuthenticated = true
                        connectionStatePublisher.send(.connected)
                        reconnectAttempts = 0
                        print("✅ Alpaca authenticated")

                        // Subscribe to pending symbols
                        if !subscribedSymbols.isEmpty {
                            subscribe(symbols: Array(subscribedSymbols))
                        }
                    }
                }

            case "t":  // Trade update
                parseTradeUpdate(json)

            case "subscription":
                if let trades = json["trades"] as? [String] {
                    print("✅ Subscribed to \(trades.count) trades")
                }

            case "error":
                if let msg = json["msg"] as? String {
                    print("❌ Alpaca error: \(msg)")
                }

            default:
                break
            }
        }
    }

    private func parseTradeUpdate(_ json: [String: Any]) {
        guard let symbol = json["S"] as? String,
            let price = json["p"] as? Double
        else {
            return
        }

        let volume = json["s"] as? Double

        let update = PriceUpdate(
            assetCode: symbol,
            price: price,
            source: "alpaca",
            volume: volume
        )

        priceUpdatePublisher.send(update)
    }

    // MARK: - Reconnection
    private func attemptReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("❌ Max reconnection attempts reached")
            connectionStatePublisher.send(.error(WebSocketError.connectionFailed))
            return
        }

        reconnectAttempts += 1
        connectionStatePublisher.send(.reconnecting)

        let delay = pow(2.0, Double(reconnectAttempts))
        print(
            "🔄 Reconnecting in \(delay) seconds (attempt \(reconnectAttempts)/\(maxReconnectAttempts))"
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect()
        }
    }
}
