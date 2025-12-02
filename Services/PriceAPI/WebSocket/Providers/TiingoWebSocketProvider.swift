import Combine
import Foundation

final class TiingoWebSocketProvider: WebSocketProvider, SubscribableProvider {
    // MARK: - Properties
    private let baseURL = "wss://api.tiingo.com/fx"
    private let apiKey: String
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?

    private var subscribedSymbols: Set<String> = []
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var pingTimer: Timer?

    // Publishers
    let priceUpdatePublisher = PassthroughSubject<PriceUpdate, Never>()
    let connectionStatePublisher = PassthroughSubject<ConnectionState, Never>()

    // SubscribableProvider conformance
    var isConnected: Bool {
        webSocket != nil
    }

    // MARK: - Initialization
    init(apiKey: String) {
        self.apiKey = apiKey
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
        print("💱 TiingoWebSocketProvider initialized")
    }

    deinit {
        disconnect()
        print("💱 TiingoWebSocketProvider deinitialized")
    }

    // MARK: - Connection Management
    func connect() {
        guard webSocket == nil else {
            print("⚠️ Already connected to Tiingo")
            return
        }

        connectionStatePublisher.send(.connecting)

        // Build URL with API token
        guard let url = URL(string: "\(baseURL)?token=\(apiKey)") else {
            connectionStatePublisher.send(.error(WebSocketError.invalidURL))
            return
        }

        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()

        connectionStatePublisher.send(.connected)
        reconnectAttempts = 0

        // Start receiving messages
        receiveMessage()

        // Start ping timer
        startPingTimer()

        print("✅ Connected to Tiingo WebSocket")
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil

        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil

        connectionStatePublisher.send(.disconnected)
        print("❌ Disconnected from Tiingo WebSocket")
    }

    // MARK: - Subscription Management
    func subscribe(symbols: [String]) {
        subscribedSymbols.formUnion(symbols)

        guard webSocket != nil else {
            connect()
            return
        }

        // Tiingo subscription message format
        let message: [String: Any] = [
            "eventName": "subscribe",
            "authorization": apiKey,
            "eventData": [
                "thresholdLevel": 5,
                "tickers": symbols.map { $0.lowercased() },
            ],
        ]

        sendMessage(message)
        print("📡 Subscribed to \(symbols.count) Tiingo forex pairs")
    }

    func unsubscribe(symbols: [String]) {
        subscribedSymbols.subtract(symbols)

        let message: [String: Any] = [
            "eventName": "unsubscribe",
            "authorization": apiKey,
            "eventData": [
                "tickers": symbols.map { $0.lowercased() }
            ],
        ]

        sendMessage(message)
        print("📡 Unsubscribed from \(symbols.count) Tiingo forex pairs")
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
                print("❌ Tiingo WebSocket error: \(error)")
                self.connectionStatePublisher.send(.error(error))
                self.attemptReconnect()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseForexMessage(text)

        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseForexMessage(text)
            }

        @unknown default:
            print("⚠️ Unknown message type")
        }
    }

    private func parseForexMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let messageType = json["messageType"] as? String
        else {
            return
        }

        // Handle different message types
        switch messageType {
        case "A":  // Quote update
            parseQuoteUpdate(json)
        case "H":  // Heartbeat
            print("💓 Tiingo heartbeat received")
        case "I":  // Info message
            if let message = json["data"] as? [String: Any],
                let response = message["response"] as? [String: Any],
                let message = response["message"] as? String
            {
                print("ℹ️ Tiingo: \(message)")
            }
        default:
            break
        }
    }

    private func parseQuoteUpdate(_ json: [String: Any]) {
        guard let dataArray = json["data"] as? [[String: Any]] else {
            return
        }

        for item in dataArray {
            guard let ticker = item["ticker"] as? String,
                let midPrice = item["midPrice"] as? Double
            else {
                continue
            }

            // Extract base currency (e.g., "eurusd" -> "EUR")
            let baseCurrency = String(ticker.prefix(3)).uppercased()

            let update = PriceUpdate(
                assetCode: baseCurrency,
                price: midPrice,
                source: "tiingo",
                volume: nil
            )

            priceUpdatePublisher.send(update)
        }
    }

    // MARK: - Ping/Pong
    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 180.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func sendPing() {
        webSocket?.sendPing { error in
            if let error = error {
                print("❌ Ping failed: \(error)")
            }
        }
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

        // Exponential backoff
        let delay = pow(2.0, Double(reconnectAttempts))
        print(
            "🔄 Reconnecting in \(delay) seconds (attempt \(reconnectAttempts)/\(maxReconnectAttempts))"
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect()

            // Re-subscribe to previous symbols
            if let symbols = self?.subscribedSymbols, !symbols.isEmpty {
                self?.subscribe(symbols: Array(symbols))
            }
        }
    }
}
