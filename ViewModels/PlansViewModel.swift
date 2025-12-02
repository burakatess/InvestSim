import Foundation
import SwiftUI
import Combine

final class PlansViewModel: ObservableObject {
    struct CalendarDay: Identifiable, Equatable {
        let date: Date
        let isWithinDisplayedMonth: Bool
        let isToday: Bool
        let hasReminder: Bool
        
        var id: Date { date }
    }
    
    struct ReminderItem: Identifiable, Equatable {
        enum State {
            case overdue
            case today
            case upcoming
            
            var labelText: String {
                switch self {
                case .overdue: return "Gecikti"
                case .today: return "Bugün"
                case .upcoming: return "Yakında"
                }
            }
            
            var color: Color {
                switch self {
                case .overdue: return .red
                case .today: return .orange
                case .upcoming: return .green
                }
            }
        }
        
        let id = UUID()
        let plan: PlanRecord
        let fireDate: Date
        let offsetDays: Int
        let state: State
    }
    
    struct HistoryItem: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let date: Date
        let note: String?
    }
    
    struct PlanCreationInput {
        var title: String
        var assetCode: String
        var amount: Decimal
        var unit: String
        var frequency: DCAFrequency
        var scheduleDay: Int
        var reminderOffsets: [Int] = [-3, -1]
    }
    
    @Published var month: Date
    @Published var selectedDate: Date
    @Published var calendarDays: [CalendarDay] = []
    @Published var reminders: [ReminderItem] = []
    @Published var history: [HistoryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isPerformingMutation = false
    
    var activePlanCount: Int { plans.count }
    var nextReminderText: String {
        guard let reminder = upcomingReminders.sorted(by: { $0.fireDate < $1.fireDate }).first else {
            return "Plan bulunmuyor"
        }
        if #available(iOS 15.0, *) {
            return reminder.fireDate.formatted(date: .abbreviated, time: .omitted)
        } else {
            return PlansViewModel.reminderDateFormatter.string(from: reminder.fireDate)
        }
    }
    
    private let repository: PlansRepository
    private let assetRepository: AssetRepository
    private let scheduler: PlanReminderScheduler
    private let calendar: Calendar
    private var plans: [PlanRecord] = []
    private var hasLoaded = false
    private var upcomingReminders: [ReminderItem] = []
    private var assetCancellable: AnyCancellable?
    @Published var assetOptions: [AssetDefinition] = []
    private static let reminderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
    
    init(repository: PlansRepository, scheduler: PlanReminderScheduler, assetRepository: AssetRepository) {
        self.repository = repository
        self.scheduler = scheduler
        self.assetRepository = assetRepository
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US")
        cal.firstWeekday = 2 // Pazartesi
        self.calendar = cal
        let today = Date()
        self.month = today
        self.selectedDate = calendar.startOfDay(for: today)
        assetOptions = assetRepository.fetchAllActive()
        assetCancellable = assetRepository.$activeAssets
            .receive(on: RunLoop.main)
            .sink { [weak self] assets in
                self?.assetOptions = assets
            }
    }
    
    func load(force: Bool = false) {
        guard !isLoading else { return }
        if hasLoaded && !force { return }
        isLoading = true
        errorMessage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let fetchedPlans = self.repository.fetchAllRecords()
            var historyItems: [HistoryItem] = []
            for plan in fetchedPlans {
                let entries = self.repository.fetchHistory(for: plan.id, limit: 3)
                let mapped = entries.map { entry in
                    HistoryItem(
                        title: plan.title,
                        date: entry.completionDate,
                        note: entry.note
                    )
                }
                historyItems.append(contentsOf: mapped)
            }
            historyItems.sort { $0.date > $1.date }
            historyItems = Array(historyItems.prefix(5))
            DispatchQueue.main.async {
                self.plans = fetchedPlans
                self.history = historyItems
                self.hasLoaded = true
                self.isLoading = false
                self.rebuildCalendar()
                self.updateReminders(for: self.selectedDate)
                self.computeUpcomingSnapshot()
            }
        }
    }
    
    func refresh() {
        hasLoaded = false
        load(force: true)
    }
    
    func goToPreviousMonth() {
        guard let newMonth = calendar.date(byAdding: .month, value: -1, to: month) else { return }
        month = newMonth
        rebuildCalendar()
    }
    
    func goToNextMonth() {
        guard let newMonth = calendar.date(byAdding: .month, value: 1, to: month) else { return }
        month = newMonth
        rebuildCalendar()
    }
    
    func select(_ day: CalendarDay) {
        selectedDate = calendar.startOfDay(for: day.date)
        updateReminders(for: selectedDate)
    }
    
    func complete(_ reminder: ReminderItem) {
        scheduler.handleCompletion(for: reminder.plan)
        refresh()
    }
    
    func skip(_ reminder: ReminderItem) {
        scheduler.skipNextReminder(for: reminder.plan)
        refresh()
    }

    func makeDefaultInput(for date: Date? = nil) -> PlanCreationInput {
        let baseDate = date ?? Date()
        let day = calendar.component(.day, from: baseDate)
        return PlanCreationInput(
            title: "",
            assetCode: assetOptions.first?.code ?? "USD",
            amount: 5,
            unit: "gram",
            frequency: .monthly,
            scheduleDay: day,
            reminderOffsets: [-3, -1]
        )
    }

    func makeInput(from plan: PlanRecord) -> PlanCreationInput {
        PlanCreationInput(
            title: plan.title,
            assetCode: plan.assetCode.rawValue,
            amount: plan.amountValue,
            unit: plan.amountUnit,
            frequency: plan.frequency,
            scheduleDay: plan.frequency == .monthly ? plan.dayOfMonth : plan.dayOfWeek,
            reminderOffsets: plan.reminderOffsets.isEmpty ? [-3, -1] : plan.reminderOffsets
        )
    }

    func plans(on date: Date) -> [PlanRecord] {
        plans.filter { record in
            if let due = record.nextDueDate {
                return calendar.isDate(due, inSameDayAs: date)
            }
            return false
        }
    }

    func createPlan(input: PlanCreationInput) {
        isPerformingMutation = true
        DispatchQueue.global(qos: .userInitiated).async {
            let assetCode = input.assetCode.isEmpty ? (self.assetOptions.first?.code ?? "USD") : input.assetCode.uppercased()
            let startDate = self.initialStartDate(for: input.frequency, scheduleDay: input.scheduleDay)
            let assetDisplayName = self.assetOptions.first(where: { $0.code == assetCode })?.displayName ?? assetCode
            let resolvedTitle = input.title.isEmpty ? "\(assetDisplayName) Planı" : input.title
            let data = PlanCreationData(
                title: resolvedTitle,
                assetCode: assetCode,
                frequency: input.frequency,
                scheduleDay: input.scheduleDay,
                amountValue: input.amount,
                amountUnit: input.unit,
                startDate: startDate,
                reminderOffsets: input.reminderOffsets,
                motivationalTone: "coach",
                messageTemplateId: nil,
                timeZoneIdentifier: TimeZone.current.identifier
            )
            _ = self.repository.createPlan(data: data)
            DispatchQueue.main.async {
                self.isPerformingMutation = false
                self.scheduler.refreshSchedules()
                self.refresh()
            }
        }
    }

    func update(plan: PlanRecord, with input: PlanCreationInput) {
        isPerformingMutation = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.repository.updatePlan(objectID: plan.objectID) { corePlan in
                    corePlan.title = input.title
                    corePlan.asset = input.assetCode
                    corePlan.assetCode = input.assetCode
                    corePlan.amountValue = NSDecimalNumber(decimal: input.amount)
                    corePlan.amountTRY = NSDecimalNumber(decimal: input.amount)
                    corePlan.amountUnit = input.unit
                    corePlan.frequency = input.frequency.rawValue
                    corePlan.dayOfMonth = Int16(input.frequency == .monthly ? input.scheduleDay : 0)
                    corePlan.dayOfWeek = Int16(input.frequency == .weekly ? input.scheduleDay : 0)
                    corePlan.reminderOffsets = input.reminderOffsets.map { NSNumber(value: $0) } as NSArray
                }
                DispatchQueue.main.async {
                    self.isPerformingMutation = false
                    self.scheduler.refreshSchedules()
                    self.refresh()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isPerformingMutation = false
                }
            }
        }
    }

    func delete(plan: PlanRecord) {
        isPerformingMutation = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.repository.deletePlan(objectID: plan.objectID)
                DispatchQueue.main.async {
                    self.isPerformingMutation = false
                    self.scheduler.refreshSchedules()
                    self.refresh()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isPerformingMutation = false
                }
            }
        }
    }
    
    private func rebuildCalendar() {
        calendarDays = buildCalendarDays(for: month)
    }
    
    private func buildCalendarDays(for month: Date) -> [CalendarDay] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmpties = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days: [CalendarDay] = []
        var current = calendar.date(byAdding: .day, value: -leadingEmpties, to: monthStart) ?? monthStart
        let totalCells = 42 // 6 weeks grid
        let reminderDates = reminderDateSet()
        for _ in 0..<totalCells {
            let normalized = calendar.startOfDay(for: current)
            let isCurrentMonth = calendar.isDate(current, equalTo: monthStart, toGranularity: .month)
            let isToday = calendar.isDateInToday(current)
            let hasReminder = reminderDates.contains(normalized)
            let day = CalendarDay(
                date: normalized,
                isWithinDisplayedMonth: isCurrentMonth,
                isToday: isToday,
                hasReminder: hasReminder
            )
            days.append(day)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return days
    }
    
    private func reminderDateSet() -> Set<Date> {
        var set: Set<Date> = []
        for plan in plans {
            guard let base = plan.nextDueDate else { continue }
            set.insert(calendar.startOfDay(for: base))
        }
        return set
    }
    
    private func updateReminders(for date: Date) {
        var items: [ReminderItem] = []
        for plan in plans {
            guard let base = plan.nextDueDate else { continue }
            let offsets = effectiveOffsets(for: plan)
            for offset in offsets {
                guard let fireDate = calendar.date(byAdding: .day, value: offset, to: base) else { continue }
                if calendar.isDate(fireDate, inSameDayAs: date) {
                    items.append(
                        ReminderItem(
                            plan: plan,
                            fireDate: fireDate,
                            offsetDays: offset,
                            state: state(for: fireDate)
                        )
                    )
                }
            }
        }
        reminders = items.sorted { $0.fireDate < $1.fireDate }
    }
    
    private func state(for date: Date) -> ReminderItem.State {
        if calendar.isDateInToday(date) {
            return .today
        }
        return date < Date() ? .overdue : .upcoming
    }
    
    private func computeUpcomingSnapshot() {
        var entries: [ReminderItem] = []
        for plan in plans {
            guard let base = plan.nextDueDate else { continue }
            let offsets = effectiveOffsets(for: plan)
            for offset in offsets {
                guard let fireDate = calendar.date(byAdding: .day, value: offset, to: base) else { continue }
                if fireDate >= calendar.startOfDay(for: Date()).addingTimeInterval(-86400) {
                    entries.append(
                        ReminderItem(
                            plan: plan,
                            fireDate: fireDate,
                            offsetDays: offset,
                            state: state(for: fireDate)
                        )
                    )
                }
            }
        }
        upcomingReminders = entries
    }
    
    private func initialStartDate(for frequency: DCAFrequency, scheduleDay: Int) -> Date {
        let now = Date()
        switch frequency {
        case .monthly:
            let targetDay = max(1, min(scheduleDay, 28))
            var components = calendar.dateComponents([.year, .month], from: now)
            components.day = targetDay
            components.hour = 9
            components.minute = 0
            let candidate = calendar.date(from: components) ?? now
            if candidate < now {
                return calendar.date(byAdding: .month, value: 1, to: candidate) ?? now
            }
            return candidate
        case .weekly:
            var weekday = scheduleDay
            if weekday < 1 || weekday > 7 { weekday = 2 }
            var comps = DateComponents()
            comps.weekday = weekday
            comps.hour = 9
            return calendar.nextDate(after: now, matching: comps, matchingPolicy: .nextTimePreservingSmallerComponents) ?? now
        }
    }
    
    private func effectiveOffsets(for plan: PlanRecord) -> [Int] {
        var offsets = plan.reminderOffsets
        offsets.append(0)
        let unique = Array(Set(offsets))
        return unique.sorted()
    }
}
