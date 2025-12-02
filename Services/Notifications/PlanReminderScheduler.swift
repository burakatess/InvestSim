import Foundation
import UserNotifications

@MainActor
protocol MotivationMessageProviding {
    func title(for plan: PlanRecord, offsetDays: Int) -> String
    func body(for plan: PlanRecord, offsetDays: Int) -> String
}

struct DefaultMotivationMessageProvider: MotivationMessageProviding {
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    func title(for plan: PlanRecord, offsetDays: Int) -> String {
        if offsetDays == 0 {
            return "Bugün \(plan.title)"
        }
        let days = abs(offsetDays)
        return "\(plan.title) için \(days) gün kaldı"
    }

    func body(for plan: PlanRecord, offsetDays: Int) -> String {
        let amountText = formattedAmount(plan)
        if offsetDays == 0 {
            return
                "Bugün \(amountText) \(plan.amountUnit) \(plan.assetCode.rawValue) alma hedefini tamamla."
        }
        if offsetDays < 0 {
            let days = abs(offsetDays)
            return
                "\(plan.assetCode.rawValue) birikimine \(days) gün sonra devam ediyorsun. \(amountText) \(plan.amountUnit) hedefini unutma!"
        }
        return "Plan hatırlatıcısı"
    }

    private func formattedAmount(_ plan: PlanRecord) -> String {
        let number = NSDecimalNumber(decimal: plan.amountValue)
        return Self.numberFormatter.string(from: number) ?? number.stringValue
    }
}

@MainActor
final class PlanReminderScheduler {
    private let repository: PlansRepository
    private let notificationManager: NotificationScheduling
    private let messageProvider: MotivationMessageProviding
    private var calendar: Calendar

    init(
        repository: PlansRepository,
        notificationManager: NotificationScheduling,
        messageProvider: MotivationMessageProviding
    ) {
        self.repository = repository
        self.notificationManager = notificationManager
        self.messageProvider = messageProvider
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        self.calendar = calendar
    }

    func refreshSchedules() {
        let plans = repository.fetchAllRecords().filter { $0.isActive }
        plans.forEach { plan in
            scheduleReminders(for: plan)
        }
    }

    func scheduleReminders(for plan: PlanRecord) {
        cancelNotifications(for: plan.id)
        var effectivePlan = plan
        if let dueDate = plan.nextDueDate, dueDate < Date() {
            let recalculatedDate = computeNextDueDate(from: Date(), plan: plan)
            updatePlan(plan, nextDueDate: recalculatedDate)
            if let recalculatedDate {
                effectivePlan = updatedPlanRecord(
                    plan, nextDueDate: recalculatedDate, lastCompletionDate: plan.lastCompletionDate
                )
            }
        }
        guard let dueDate = effectivePlan.nextDueDate else {
            return
        }
        var snapshots: [PlanNotificationSnapshot] = []
        let sortedOffsets = effectivePlan.reminderOffsets.sorted()
        for offset in sortedOffsets {
            guard let fireDate = calendar.date(byAdding: .day, value: offset, to: dueDate) else {
                continue
            }
            if fireDate < Date() { continue }
            let identifier = notificationIdentifier(
                for: plan.id, offset: offset, fireDate: fireDate)
            let trigger = makeTrigger(
                for: fireDate, timeZoneIdentifier: effectivePlan.timeZoneIdentifier)
            let title = messageProvider.title(for: effectivePlan, offsetDays: offset)
            let body = messageProvider.body(for: effectivePlan, offsetDays: offset)
            notificationManager.scheduleNotification(
                title: title,
                body: body,
                identifier: identifier,
                trigger: trigger
            )
            let snapshot = PlanNotificationSnapshot(
                id: UUID(),
                planId: plan.id,
                fireDate: fireDate,
                offsetDays: offset,
                notificationId: identifier,
                state: "scheduled"
            )
            snapshots.append(snapshot)
        }
        repository.replaceNotificationRecords(planId: plan.id, records: snapshots)
    }

    func cancelNotifications(for planId: UUID) {
        let records = repository.fetchNotificationRecords(planId: planId)
        records.forEach { record in
            notificationManager.cancelNotification(identifier: record.notificationId)
        }
        repository.replaceNotificationRecords(planId: planId, records: [])
    }

    func handleCompletion(for plan: PlanRecord, completionDate: Date = Date(), note: String? = nil)
    {
        repository.appendHistoryEntry(planId: plan.id, completionDate: completionDate, note: note)
        let nextDueDate = computeNextDueDate(from: completionDate, plan: plan)
        updatePlan(plan, nextDueDate: nextDueDate, lastCompletionDate: completionDate)
        cancelNotifications(for: plan.id)
        if let nextDueDate {
            let updatedPlan = updatedPlanRecord(
                plan, nextDueDate: nextDueDate, lastCompletionDate: completionDate)
            scheduleReminders(for: updatedPlan)
        }
    }

    func skipNextReminder(for plan: PlanRecord) {
        guard let next = plan.nextDueDate else { return }
        let newReference = calendar.date(byAdding: .day, value: 1, to: next) ?? Date()
        let nextDueDate = computeNextDueDate(from: newReference, plan: plan)
        updatePlan(plan, nextDueDate: nextDueDate)
        if let nextDueDate {
            let updatedPlan = updatedPlanRecord(
                plan, nextDueDate: nextDueDate, lastCompletionDate: plan.lastCompletionDate)
            scheduleReminders(for: updatedPlan)
        }
    }
}

extension PlanReminderScheduler {
    fileprivate func makeTrigger(for date: Date, timeZoneIdentifier: String)
        -> UNNotificationTrigger
    {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    fileprivate func notificationIdentifier(for planId: UUID, offset: Int, fireDate: Date) -> String
    {
        "plan_\(planId.uuidString)_offset_\(offset)_\(Int(fireDate.timeIntervalSince1970))"
    }

    fileprivate func updatePlan(
        _ plan: PlanRecord,
        nextDueDate: Date?,
        lastCompletionDate: Date? = nil
    ) {
        try? repository.updatePlan(objectID: plan.objectID) { coreDataPlan in
            coreDataPlan.nextDueDate = nextDueDate
            if let lastCompletionDate {
                coreDataPlan.lastCompletionDate = lastCompletionDate
            }
        }
    }

    fileprivate func updatedPlanRecord(
        _ plan: PlanRecord,
        nextDueDate: Date?,
        lastCompletionDate: Date?
    ) -> PlanRecord {
        PlanRecord(
            id: plan.id,
            objectID: plan.objectID,
            title: plan.title,
            assetCode: plan.assetCode,
            frequency: plan.frequency,
            amountValue: plan.amountValue,
            amountUnit: plan.amountUnit,
            dayOfMonth: plan.dayOfMonth,
            dayOfWeek: plan.dayOfWeek,
            reminderOffsets: plan.reminderOffsets,
            motivationalTone: plan.motivationalTone,
            messageTemplateId: plan.messageTemplateId,
            isActive: plan.isActive,
            startDate: plan.startDate,
            nextDueDate: nextDueDate,
            lastCompletionDate: lastCompletionDate,
            timeZoneIdentifier: plan.timeZoneIdentifier,
            createdAt: plan.createdAt,
            updatedAt: Date()
        )
    }

    fileprivate func computeNextDueDate(from reference: Date, plan: PlanRecord) -> Date? {
        let timezone = TimeZone(identifier: plan.timeZoneIdentifier) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        switch plan.frequency {
        case .monthly:
            let clampedDay = max(1, plan.dayOfMonth)
            var candidate = makeMonthlyDate(from: reference, day: clampedDay, calendar: calendar)
            if let candidateDate = candidate, candidateDate <= reference {
                if let advanced = calendar.date(byAdding: .month, value: 1, to: candidateDate) {
                    candidate = makeMonthlyDate(from: advanced, day: clampedDay, calendar: calendar)
                }
            }
            return candidate
        case .weekly:
            var nextWeekday = plan.dayOfWeek
            if nextWeekday < 1 || nextWeekday > 7 {
                nextWeekday = 2
            }
            let components = DateComponents(hour: 9, weekday: nextWeekday)
            return calendar.nextDate(
                after: reference, matching: components,
                matchingPolicy: .nextTimePreservingSmallerComponents)
        }
    }

    fileprivate func makeMonthlyDate(from reference: Date, day: Int, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month], from: reference)
        let range = calendar.range(of: .day, in: .month, for: reference)
        let maxDay = (range?.upperBound ?? (day + 1)) - 1
        components.day = min(day, maxDay)
        components.hour = 9
        components.minute = 0
        return calendar.date(from: components)
    }
}
