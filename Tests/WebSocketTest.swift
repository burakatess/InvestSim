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
                    "📈 [\(String(format: "%.1f", elapsed))s] \(update.symbol): $\(String(format: "%.2f", update.price))"
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
// MARK: - PlansViewModel Test Runner
@MainActor
final class PlansViewModelTestRunner {
    private var viewModel: PlansViewModel!
    private var repository: PlansRepository!
    private var assetRepository: AssetRepository!
    private var scheduler: PlanReminderScheduler!
    private var mockNotificationManager: MockNotificationManager!
    private var coreDataStack: CoreDataStack!
    private var cancellables: Set<AnyCancellable> = []

    func runTests() async {
        print("\n🧪 Starting PlansViewModel Tests...")
        print("=" + String(repeating: "=", count: 50))

        setUp()
        await testInitialState()
        tearDown()

        setUp()
        await testLoadPlans()
        tearDown()

        setUp()
        await testCreatePlanSchedulesNotifications()
        tearDown()

        setUp()
        await testCompletePlan()
        tearDown()

        print("=" + String(repeating: "=", count: 50))
        print("✅ PlansViewModel Tests Complete!")
    }

    private func setUp() {
        // Use in-memory store
        coreDataStack = CoreDataStack.shared

        // Clear existing data
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(
            entityName: "DCAPlan")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try? coreDataStack.viewContext.execute(deleteRequest)

        repository = PlansRepository(context: coreDataStack.viewContext)
        assetRepository = AssetRepository(context: coreDataStack.viewContext)
        mockNotificationManager = MockNotificationManager()

        scheduler = PlanReminderScheduler(
            repository: repository,
            notificationManager: mockNotificationManager,
            messageProvider: MockMotivationMessageProvider()
        )

        viewModel = PlansViewModel(
            repository: repository,
            scheduler: scheduler,
            assetRepository: assetRepository
        )
    }

    private func tearDown() {
        viewModel = nil
        scheduler = nil
        repository = nil
        mockNotificationManager = nil
        cancellables.removeAll()
    }

    private func testInitialState() async {
        print("🔹 Test: Initial State")
        assert(viewModel.calendarDays.isEmpty, "Calendar days should be empty initially")
        assert(viewModel.reminders.isEmpty, "Reminders should be empty initially")
        assert(viewModel.activePlanCount == 0, "Active plan count should be 0")
        print("   ✅ Passed")
    }

    private func testLoadPlans() async {
        print("🔹 Test: Load Plans")
        let input = PlansViewModel.PlanCreationInput(
            title: "Test Plan",
            assetCode: "USD",
            amount: 100,
            unit: "USD",
            frequency: .monthly,
            scheduleDay: 15,
            reminderOffsets: [-1]
        )
        viewModel.createPlan(input: input)

        // Wait for async creation
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        viewModel.load(force: true)

        // Wait for load
        try? await Task.sleep(nanoseconds: 500_000_000)

        assert(viewModel.activePlanCount == 1, "Should have 1 active plan")
        print("   ✅ Passed")
    }

    private func testCreatePlanSchedulesNotifications() async {
        print("🔹 Test: Create Plan Schedules Notifications")
        let input = PlansViewModel.PlanCreationInput(
            title: "Notification Plan",
            assetCode: "GOLD",
            amount: 10,
            unit: "gram",
            frequency: .monthly,
            scheduleDay: 1,
            reminderOffsets: [-3, -1]
        )

        viewModel.createPlan(input: input)

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        assert(
            !mockNotificationManager.scheduledNotifications.isEmpty,
            "Should have scheduled notifications")
        print("   ✅ Passed")
    }

    private func testCompletePlan() async {
        print("🔹 Test: Complete Plan")
        let input = PlansViewModel.PlanCreationInput(
            title: "Completion Plan",
            assetCode: "EUR",
            amount: 50,
            unit: "EUR",
            frequency: .weekly,
            scheduleDay: 2,
            reminderOffsets: [-1]
        )
        viewModel.createPlan(input: input)

        try? await Task.sleep(nanoseconds: 1_000_000_000)
        viewModel.load(force: true)
        try? await Task.sleep(nanoseconds: 500_000_000)

        guard let plan = repository.fetchAllRecords().first else {
            print("   ❌ Failed: Plan not found")
            return
        }

        let initialDueDate = plan.nextDueDate

        let reminder = PlansViewModel.ReminderItem(
            plan: plan,
            fireDate: Date(),
            offsetDays: 0,
            state: .today
        )
        viewModel.complete(reminder)

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        let updatedPlan = repository.fetchAllRecords().first
        assert(updatedPlan?.nextDueDate != initialDueDate, "Next due date should update")
        assert(updatedPlan?.lastCompletionDate != nil, "Last completion date should be set")
        print("   ✅ Passed")
    }
}

// MARK: - Mocks for Runner
class MockNotificationManager: NotificationScheduling {
    var scheduledNotifications:
        [String: (title: String, body: String, trigger: UNNotificationTrigger?)] = [:]
    var cancelledNotifications: Set<String> = []
    var permissionGranted = true

    func requestPermission() async -> Bool {
        return permissionGranted
    }

    func scheduleNotification(
        title: String, body: String, identifier: String, trigger: UNNotificationTrigger?
    ) {
        scheduledNotifications[identifier] = (title, body, trigger)
    }

    func cancelNotification(identifier: String) {
        cancelledNotifications.insert(identifier)
        scheduledNotifications.removeValue(forKey: identifier)
    }

    func cancelAllNotifications() {
        scheduledNotifications.removeAll()
    }
}

class MockMotivationMessageProvider: MotivationMessageProviding {
    func title(for plan: PlanRecord, offsetDays: Int) -> String {
        return "Mock Title \(offsetDays)"
    }

    func body(for plan: PlanRecord, offsetDays: Int) -> String {
        return "Mock Body \(offsetDays)"
    }
}
