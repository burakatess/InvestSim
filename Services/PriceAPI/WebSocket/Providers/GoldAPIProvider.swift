import Combine
import Foundation

final class GoldAPIProvider: SubscribableProvider {
    // MARK: - Properties
    private let baseURL = "https://www.goldapi.io/api"
    private let apiKey: String
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Publishers
    let priceUpdatePublisher = PassthroughSubject<PriceUpdate, Never>()
    let connectionStatePublisher = PassthroughSubject<ConnectionState, Never>()

    // Supported metals
    private let metals = ["XAU", "XAG", "XPT", "XPD"]
    private var isPolling = false

    // SubscribableProvider conformance
    var isConnected: Bool {
        isPolling
    }

    // MARK: - Initialization
    init(apiKey: String) {
        self.apiKey = apiKey
        print("🥇 GoldAPIProvider initialized")
    }

    deinit {
        stopPolling()
        print("🥇 GoldAPIProvider deinitialized")
    }

    // MARK: - Polling Management
    func startPolling() {
        guard !isPolling else {
            print("⚠️ Already polling GoldAPI")
            return
        }

        isPolling = true
        connectionStatePublisher.send(.connected)

        // Fetch immediately
        fetchAllPrices()

        // Then poll every 30 seconds (API rate limit)
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.fetchAllPrices()
        }

        print("✅ Started GoldAPI polling (30s interval)")
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
        isPolling = false
        connectionStatePublisher.send(.disconnected)
        print("❌ Stopped GoldAPI polling")
    }

    // MARK: - Price Fetching
    private func fetchAllPrices() {
        metals.forEach { metal in
            fetchPrice(for: metal)
        }
    }

    private func fetchPrice(for metal: String) {
        // Endpoint: https://www.goldapi.io/api/XAU/USD
        guard let url = URL(string: "\(baseURL)/\(metal)/USD") else {
            return
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-access-token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ GoldAPI error for \(metal): \(error)")
                return
            }

            guard let data = data else { return }

            self.parseResponse(data, for: metal)
        }.resume()
    }

    private func parseResponse(_ data: Data, for metal: String) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let price = json["price"] as? Double
            else {
                return
            }

            let update = PriceUpdate(
                assetCode: metal,
                price: price,
                source: "goldapi",
                volume: nil
            )

            DispatchQueue.main.async {
                self.priceUpdatePublisher.send(update)
            }

            print("💰 GoldAPI: \(metal) = $\(price)")

        } catch {
            print("❌ Failed to parse GoldAPI response: \(error)")
        }
    }
}

// MARK: - WebSocketProvider Conformance (for compatibility)
extension GoldAPIProvider: WebSocketProvider {
    func connect() {
        startPolling()
    }

    func disconnect() {
        stopPolling()
    }

    func subscribe(symbols: [String]) {
        // GoldAPI doesn't support selective subscription
        // It always fetches all metals
        startPolling()
    }

    func unsubscribe(symbols: [String]) {
        // Not applicable for polling
    }
}
