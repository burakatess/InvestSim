import Combine
import CoreData
import UserNotifications
import XCTest

@testable import InvestSimulator_v2_21_11_2025

// MARK: - Mocks

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

@MainActor
class PlansViewModelTests: XCTestCase {
    var viewModel: PlansViewModel!
    var repository: PlansRepository!
    var assetRepository: AssetRepository!
    var scheduler: PlanReminderScheduler!
    var mockNotificationManager: MockNotificationManager!
    var coreDataStack: CoreDataStack!
    var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
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

    override func tearDown() {
        viewModel = nil
        scheduler = nil
        repository = nil
        mockNotificationManager = nil
        cancellables.removeAll()
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertTrue(viewModel.calendarDays.isEmpty)
        XCTAssertTrue(viewModel.reminders.isEmpty)
        XCTAssertEqual(viewModel.activePlanCount, 0)
    }

    func testLoadPlans() {
        // Given
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

        // When
        let expectation = XCTestExpectation(description: "Load plans")

        // Wait for async creation to finish (it uses global queue)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.viewModel.load(force: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Then
        XCTAssertEqual(viewModel.activePlanCount, 1)
        XCTAssertEqual(viewModel.plans(on: Date()).count, 0)  // Likely not today unless today is 15th
    }

    func testCreatePlanSchedulesNotifications() {
        // Given
        let input = PlansViewModel.PlanCreationInput(
            title: "Notification Plan",
            assetCode: "GOLD",
            amount: 10,
            unit: "gram",
            frequency: .monthly,
            scheduleDay: 1,
            reminderOffsets: [-3, -1]
        )

        // When
        viewModel.createPlan(input: input)

        let expectation = XCTestExpectation(description: "Create plan")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // Then
        // We expect notifications to be scheduled.
        // Note: The exact number depends on the calculated nextDueDate and offsets.
        // If nextDueDate is in the past, it recalculates.
        XCTAssertFalse(
            mockNotificationManager.scheduledNotifications.isEmpty,
            "Should have scheduled notifications")
    }

    func testCompletePlan() {
        // Given
        let input = PlansViewModel.PlanCreationInput(
            title: "Completion Plan",
            assetCode: "EUR",
            amount: 50,
            unit: "EUR",
            frequency: .weekly,
            scheduleDay: 2,  // Tuesday
            reminderOffsets: [-1]
        )
        viewModel.createPlan(input: input)

        let expectation = XCTestExpectation(description: "Plan created")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.viewModel.load(force: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2.0)

        guard let plan = repository.fetchAllRecords().first else {
            XCTFail("Plan not found")
            return
        }

        let initialDueDate = plan.nextDueDate

        // When
        // Construct a dummy reminder item to complete
        let reminder = PlansViewModel.ReminderItem(
            plan: plan,
            fireDate: Date(),
            offsetDays: 0,
            state: .today
        )
        viewModel.complete(reminder)

        let completeExpectation = XCTestExpectation(description: "Plan completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completeExpectation.fulfill()
        }
        wait(for: [completeExpectation], timeout: 2.0)

        // Then
        let updatedPlan = repository.fetchAllRecords().first
        XCTAssertNotEqual(
            updatedPlan?.nextDueDate, initialDueDate, "Next due date should update after completion"
        )
        XCTAssertNotNil(updatedPlan?.lastCompletionDate, "Last completion date should be set")
    }
}
