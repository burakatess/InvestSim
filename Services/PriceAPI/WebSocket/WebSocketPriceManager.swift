import Combine
import Foundation

// Import WebSocket models and protocols

final class WebSocketPriceManager: ObservableObject {
    // MARK: - Properties
    private var providers: [String: WebSocketProvider] = [:]
    private var cancellables = Set<AnyCancellable>()

    // Unified price update stream
    let priceUpdatePublisher = PassthroughSubject<PriceUpdate, Never>()

    // Connection states
    @Published var connectionStates: [String: ConnectionState] = [:]

    // MARK: - Initialization
    init() {
        print("🔌 WebSocketPriceManager initialized")
    }

    deinit {
        disconnectAll()
        print("🔌 WebSocketPriceManager deinitialized")
    }

    // MARK: - Provider Management
    func addProvider(_ provider: WebSocketProvider, withKey key: String) {
        providers[key] = provider

        // Subscribe to provider's price updates
        provider.priceUpdatePublisher
            .sink { [weak self] update in
                self?.priceUpdatePublisher.send(update)
            }
            .store(in: &cancellables)

        // Subscribe to provider's connection state
        provider.connectionStatePublisher
            .sink { [weak self] state in
                self?.connectionStates[key] = state
            }
            .store(in: &cancellables)

        print("✅ Provider '\(key)' added")
    }

    func removeProvider(withKey key: String) {
        providers[key]?.disconnect()
        providers.removeValue(forKey: key)
        connectionStates.removeValue(forKey: key)
        print("❌ Provider '\(key)' removed")
    }

    // MARK: - Connection Management
    func connectAll() {
        providers.values.forEach { $0.connect() }
        print("🔌 Connecting all providers...")
    }

    func disconnectAll() {
        providers.values.forEach { $0.disconnect() }
        cancellables.removeAll()
        print("🔌 Disconnected all providers")
    }

    func connect(providerKey: String) {
        providers[providerKey]?.connect()
    }

    func disconnect(providerKey: String) {
        providers[providerKey]?.disconnect()
    }

    // MARK: - Subscription Management
    func subscribe(symbols: [String], providerKey: String) {
        providers[providerKey]?.subscribe(symbols: symbols)
        print("📡 Subscribed to \(symbols.count) symbols on '\(providerKey)'")
    }

    func unsubscribe(symbols: [String], providerKey: String) {
        providers[providerKey]?.unsubscribe(symbols: symbols)
        print("📡 Unsubscribed from \(symbols.count) symbols on '\(providerKey)'")
    }
}
