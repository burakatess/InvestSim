import Combine
import Foundation

final class BinanceWebSocketProvider: NSObject, WebSocketProvider, SubscribableProvider {
    // MARK: - Properties
    private let baseURL = "wss://stream.binance.com:9443/stream"
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
    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        print("📊 BinanceWebSocketProvider initialized")
    }

    deinit {
        disconnect()
        print("📊 BinanceWebSocketProvider deinitialized")
    }

    // MARK: - Connection Management
    func connect() {
        guard webSocket == nil else { return }

        connectionStatePublisher.send(.connecting)

        // Build streams URL
        // Note: URL length limit might be an issue if we subscribe to too many at once via URL.
        // Better to connect to base URL and send SUBSCRIBE messages.
        let urlString = baseURL

        guard let url = URL(string: urlString) else {
            connectionStatePublisher.send(.error(WebSocketError.invalidURL))
            return
        }

        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()

        // Note: We do NOT send .connected here. We wait for didOpen delegate.
        receiveMessage()
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil

        // Clear pending subscriptions
        pendingSubscriptions.removeAll()
        pendingUnsubscriptions.removeAll()
        subscriptionDebounceTimer?.invalidate()

        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil

        connectionStatePublisher.send(.disconnected)
        print("❌ Disconnected from Binance WebSocket")
    }

    // MARK: - Subscription Management
    private var pendingSubscriptions: Set<String> = []
    private var pendingUnsubscriptions: Set<String> = []
    private var subscriptionDebounceTimer: Timer?

    // Track if socket is actually open (handshake complete)
    private var isSocketOpen = false

    func subscribe(symbols: [String]) {
        let newSymbols = symbols.filter { !subscribedSymbols.contains($0) }
        guard !newSymbols.isEmpty else { return }

        for symbol in newSymbols {
            subscribedSymbols.insert(symbol)
            pendingSubscriptions.insert(symbol)
            // If it was pending unsubscribe, remove it
            pendingUnsubscriptions.remove(symbol)
        }

        // If we are already polling OR permanently switched, use polling
        if isPolling || permanentlySwitchToPolling {
            if !isPolling { startPolling() }
            fetchPrices()
        } else {
            // If socket not open, connect. Subscriptions will be sent in didOpen.
            if webSocket == nil {
                connect()
            } else if isSocketOpen {
                scheduleSubscriptionBatch()
            }
        }
    }

    func unsubscribe(symbols: [String]) {
        let symbolsToRemove = symbols.filter { subscribedSymbols.contains($0) }
        guard !symbolsToRemove.isEmpty else { return }

        for symbol in symbolsToRemove {
            subscribedSymbols.remove(symbol)
            pendingUnsubscriptions.insert(symbol)
            // If it was pending subscribe, remove it
            pendingSubscriptions.remove(symbol)
        }

        if isPolling {
            if subscribedSymbols.isEmpty {
                stopPolling()
            }
        } else {
            if isSocketOpen {
                scheduleSubscriptionBatch()
            }
        }
    }

    private func scheduleSubscriptionBatch() {
        subscriptionDebounceTimer?.invalidate()
        subscriptionDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) {
            [weak self] _ in
            self?.flushPendingSubscriptions()
        }
    }

    private func flushPendingSubscriptions() {
        guard isSocketOpen else { return }

        if !pendingSubscriptions.isEmpty {
            let batch = Array(pendingSubscriptions)
            sendSubscription(symbols: batch, isSubscribe: true)
            pendingSubscriptions.removeAll()
        }

        if !pendingUnsubscriptions.isEmpty {
            let batch = Array(pendingUnsubscriptions)
            sendSubscription(symbols: batch, isSubscribe: false)
            pendingUnsubscriptions.removeAll()
        }
    }

    private func sendSubscription(symbols: [String], isSubscribe: Bool) {
        // Binance limit: 1024 streams per connection.
        // We should batch them in chunks if too large, but for now just send all.
        // Also URL length limit doesn't apply to WebSocket frames, but frame size might.
        // Chunk into 50s just to be safe.
        let chunks = symbols.chunked(into: 50)

        for chunk in chunks {
            let method = isSubscribe ? "SUBSCRIBE" : "UNSUBSCRIBE"
            let params = chunk.map { "\($0.lowercased())usdt@trade" }
            let id = Int.random(in: 1...100000)
            let message: [String: Any] = [
                "method": method,
                "params": params,
                "id": id,
            ]

            guard let data = try? JSONSerialization.data(withJSONObject: message),
                let string = String(data: data, encoding: .utf8)
            else { continue }

            let wsMessage = URLSessionWebSocketTask.Message.string(string)
            webSocket?.send(wsMessage) { error in
                if let error = error {
                    print("❌ Failed to send \(method) message: \(error)")
                }
            }
        }
    }

    // MARK: - Message Handling
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                // Continue receiving
                self.receiveMessage()

            case .failure(let error):
                print("❌ Binance WebSocket error: \(error)")
                self.connectionStatePublisher.send(.error(error))
                self.attemptReconnect()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseTradeMessage(text)

        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseTradeMessage(text)
            }

        @unknown default:
            print("⚠️ Unknown message type")
        }
    }

    private func parseTradeMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let streamData = json["data"] as? [String: Any],
            let symbol = streamData["s"] as? String,
            let priceString = streamData["p"] as? String,
            let price = Double(priceString)
        else {
            return
        }

        // Extract base symbol (remove USDT)
        let baseSymbol = symbol.replacingOccurrences(of: "USDT", with: "")

        // Get volume if available
        let volume = (streamData["q"] as? String).flatMap { Double($0) }

        let update = PriceUpdate(
            assetCode: baseSymbol,
            price: price,
            source: "binance",
            volume: volume
        )

        priceUpdatePublisher.send(update)
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

    // MARK: - Polling Fallback
    private var isPolling = false
    private var pollTimer: Timer?
    private var permanentlySwitchToPolling = false

    private func startPolling() {
        guard !isPolling else { return }
        isPolling = true
        print("⚠️ Switching to Binance REST Polling (Fallback)")

        // Poll every 5 seconds
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.fetchPrices()
        }
        // Initial fetch
        fetchPrices()
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        isPolling = false
    }

    private func fetchPrices() {
        guard !subscribedSymbols.isEmpty else { return }

        // Binance API supports single symbol or all symbols.
        // For efficiency with many symbols, we might fetch all and filter, or fetch individually.
        // Fetching all is actually quite efficient for Binance (~2MB JSON).
        // Or we can batch requests. Let's try fetching specific symbols if count is small, else all.

        // For now, simple loop for specific symbols to avoid 2MB payload overhead if we only have 3-4 assets.
        for symbol in subscribedSymbols {
            let pair = "\(symbol.uppercased())USDT"
            let urlString = "https://api.binance.com/api/v3/ticker/price?symbol=\(pair)"

            guard let url = URL(string: urlString) else { continue }

            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self, let data = data else { return }
                self.parseRestResponse(data, symbol: symbol)
            }.resume()
        }
    }

    private func parseRestResponse(_ data: Data, symbol: String) {
        // {"symbol":"BTCUSDT","price":"95000.00"}
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let priceStr = json["price"] as? String,
            let price = Double(priceStr)
        else { return }

        let update = PriceUpdate(
            assetCode: symbol,
            price: price,
            source: "binance",
            volume: nil
        )

        DispatchQueue.main.async {
            self.priceUpdatePublisher.send(update)
        }
    }

    // MARK: - Reconnection
    private func attemptReconnect() {
        // If we hit a TLS error or max attempts, switch to polling
        if reconnectAttempts >= maxReconnectAttempts {
            print("❌ Max reconnection attempts reached. Switching to Polling.")
            startPolling()
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
        }
    }
}

extension BinanceWebSocketProvider: URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Trust the server regardless of the certificate validation (for debugging/simulator issues)
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let trust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }

    func urlSession(
        _ session: URLSession, webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        print("✅ Binance WebSocket Connected")
        isSocketOpen = true
        connectionStatePublisher.send(.connected)
        startPingTimer()

        // Flush any pending subscriptions
        flushPendingSubscriptions()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        isSocketOpen = false
        if let error = error {
            print("❌ Binance WebSocket Task Error: \(error)")

            // Check for TLS/SSL errors (Code -1200) or other connection failures
            let nsError = error as NSError
            if nsError.code == -1200 || nsError.code == -9816 || nsError.code == -9800 {
                print("🔒 SSL/TLS Error detected. Permanently switching to REST Polling.")
                // Clear websocket to prevent further attempts on this task
                webSocket = nil
                permanentlySwitchToPolling = true
                startPolling()
            } else {
                // For other errors, try standard reconnect
                connectionStatePublisher.send(.error(error))
                attemptReconnect()
            }
        } else {
            print("✅ Binance WebSocket Task Completed (Closed)")
            connectionStatePublisher.send(.disconnected)
        }
    }
}

// MARK: - Binance Message Models
private struct BinanceTradeMessage: Codable {
    let stream: String
    let data: TradeData

    struct TradeData: Codable {
        let s: String  // Symbol
        let p: String  // Price
        let q: String  // Quantity
        let T: Int64  // Trade time
    }
}
