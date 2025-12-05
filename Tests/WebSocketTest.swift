import Combine
import Foundation

/// Isolated test for WebSocket infrastructure
/// Run this to verify WebSocket providers work independently
@MainActor
final class WebSocketTest {
    private let priceManager = UnifiedPriceManager.shared
    private var cancellables = Set<AnyCancellable>()

    func runTests() async {
        print("🧪 Starting WebSocket Tests...")
        print("=" + String(repeating: "=", count: 50))

        // Test 1: Check WebSocket states
        await testWebSocketStates()

        // Test 2: Fetch crypto prices
        await testCryptoPrices()

        // Test 3: Listen to real-time updates
        await testRealtimeUpdates()

        print("=" + String(repeating: "=", count: 50))
        print("✅ WebSocket Tests Complete!")
    }

    // MARK: - Test 1: WebSocket States
    private func testWebSocketStates() async {
        print("\n📡 Test 1: WebSocket Connection States")
        print("-" + String(repeating: "-", count: 50))

        let states = priceManager.getWebSocketStates()

        for (provider, state) in states {
            let emoji = state == .connected ? "✅" : "⏳"
            print("\(emoji) \(provider): \(state)")
        }

        // Wait a bit for connections
        try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        let updatedStates = priceManager.getWebSocketStates()
        print("\n📊 After 2 seconds:")
        for (provider, state) in updatedStates {
            let emoji = state == .connected ? "✅" : state == .connecting ? "⏳" : "❌"
            print("\(emoji) \(provider): \(state)")
        }
    }

    // MARK: - Test 2: Crypto Prices
    private func testCryptoPrices() async {
        print("\n💰 Test 2: Fetching Crypto Prices")
        print("-" + String(repeating: "-", count: 50))

        let testSymbols = ["BTC", "ETH", "BNB", "SOL", "XRP"]

        for symbol in testSymbols {
            do {
                let price = try await priceManager.price(for: symbol)
                print("✅ \(symbol): $\(String(format: "%.2f", price))")
            } catch {
                print("❌ \(symbol): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Test 3: Real-time Updates
    private func testRealtimeUpdates() async {
        print("\n🔄 Test 3: Real-time Price Updates")
        print("-" + String(repeating: "-", count: 50))
        print("Listening for 10 seconds...")

        var updateCount = 0
        let startTime = Date()

        // Subscribe to price updates
        priceManager.priceUpdatePublisher
            .sink { update in
                updateCount += 1
                let elapsed = Date().timeIntervalSince(startTime)
                print(
                    "📈 [\(String(format: "%.1f", elapsed))s] \(update.assetCode): $\(String(format: "%.2f", update.price))"
                )
            }
            .store(in: &cancellables)

        // Wait 10 seconds
        try? await Task.sleep(nanoseconds: 10_000_000_000)

        print("\n📊 Received \(updateCount) price updates in 10 seconds")
        print("📈 Average: \(String(format: "%.1f", Double(updateCount) / 10.0)) updates/second")
    }
}

// MARK: - Run Tests
// Uncomment to run:
