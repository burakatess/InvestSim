import CoreData
import Foundation

struct PlanRecord: Equatable, Identifiable {
    let id: UUID
    let objectID: NSManagedObjectID
    let title: String
    let assetCode: AssetCode
    let frequency: DCAFrequency
    let amountValue: Decimal
    let amountUnit: String
    let dayOfMonth: Int
    let dayOfWeek: Int
    let reminderOffsets: [Int]
    let motivationalTone: String
    let messageTemplateId: String?
    let isActive: Bool
    let startDate: Date?
    let nextDueDate: Date?
    let lastCompletionDate: Date?
    let timeZoneIdentifier: String
    let createdAt: Date?
    let updatedAt: Date?
}

struct PlanCreationData {
    let title: String
    let assetCode: String
    let frequency: DCAFrequency
    let scheduleDay: Int
    let amountValue: Decimal
    let amountUnit: String
    let startDate: Date
    let reminderOffsets: [Int]
    let motivationalTone: String
    let messageTemplateId: String?
    let timeZoneIdentifier: String
}

struct PlanHistoryRecord: Equatable, Identifiable {
    let id: UUID
    let planId: UUID
    let completionDate: Date
    let note: String?
    let createdAt: Date?
}

struct PlanNotificationSnapshot: Equatable, Identifiable {
    let id: UUID
    let planId: UUID
    let fireDate: Date
    let offsetDays: Int
    let notificationId: String
    let state: String?
}

final class PlansRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchAllRecords() -> [PlanRecord] {
        var records: [PlanRecord] = []
        context.performAndWait {
            let request: NSFetchRequest<DCAPlan> = DCAPlan.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: true),
                NSSortDescriptor(key: "title", ascending: true),
            ]
            do {
                let plans = try context.fetch(request)
                var needsSave = false
                records = plans.compactMap { plan in
                    if normalize(plan) {
                        needsSave = true
                    }
                    return mapPlanRecord(plan)
                }
                if needsSave {
                    try context.save()
                }
            } catch {
                print("Failed to fetch plans: \(error)")
            }
        }
        return records
    }

    func fetchAll() -> [DCAPlan] {
        var plans: [DCAPlan] = []
        context.performAndWait {
            let request: NSFetchRequest<DCAPlan> = DCAPlan.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: true)
            ]
            do {
                plans = try context.fetch(request)
                var needsSave = false
                plans.forEach { plan in
                    if normalize(plan) {
                        needsSave = true
                    }
                }
                if needsSave {
                    try context.save()
                }
            } catch {
                print("Failed to fetch plans: \(error)")
            }
        }
        return plans
    }

    func fetchActivePlans() -> [DCAPlan] {
        var plans: [DCAPlan] = []
        context.performAndWait {
            let request: NSFetchRequest<DCAPlan> = DCAPlan.fetchRequest()
            request.predicate = NSPredicate(format: "isActive == YES")
            do {
                plans = try context.fetch(request)
            } catch {
                print("Failed to fetch active plans: \(error)")
            }
        }
        return plans
    }

    @discardableResult
    func createPlan(data: PlanCreationData) -> DCAPlan? {
        var createdPlan: DCAPlan?
        context.performAndWait {
            let plan = DCAPlan(context: context)
            plan.id = UUID()
            plan.title = data.title
            plan.asset = data.assetCode
            plan.assetCode = data.assetCode
            plan.startDate = data.startDate
            plan.frequency = data.frequency.rawValue
            plan.amountValue = NSDecimalNumber(decimal: data.amountValue)
            plan.amountTRY = NSDecimalNumber(decimal: data.amountValue)
            plan.amountUnit = data.amountUnit
            plan.dayOfMonth = Int16(data.frequency == .monthly ? data.scheduleDay : 0)
            plan.dayOfWeek = Int16(data.frequency == .weekly ? data.scheduleDay : 0)
            plan.isActive = true
            plan.createdAt = Date()
            plan.updatedAt = Date()
            plan.motivationalTone = data.motivationalTone
            plan.messageTemplateId = data.messageTemplateId
            plan.timeZoneIdentifier = data.timeZoneIdentifier
            plan.reminderOffsets = reminderArray(from: data.reminderOffsets)
            plan.nextDueDate = data.startDate
            createdPlan = plan
            do {
                try context.save()
            } catch {
                print("Failed to create plan: \(error)")
            }
        }
        return createdPlan
    }

    func updatePlan(objectID: NSManagedObjectID, perform updates: (DCAPlan) -> Void) throws {
        var storedError: Error?
        context.performAndWait {
            guard let plan = try? context.existingObject(with: objectID) as? DCAPlan else {
                storedError = NSError(
                    domain: "PlansRepository", code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Plan not found"])
                return
            }
            updates(plan)
            plan.updatedAt = Date()
            do {
                try context.save()
            } catch {
                storedError = error
            }
        }
        if let error = storedError {
            throw error
        }
    }

    func setActive(objectID: NSManagedObjectID, isActive: Bool) throws {
        try updatePlan(objectID: objectID) { plan in
            plan.isActive = isActive
        }
    }

    func deletePlan(objectID: NSManagedObjectID) throws {
        var storedError: Error?
        context.performAndWait {
            do {
                if let plan = try context.existingObject(with: objectID) as? DCAPlan {
                    context.delete(plan)
                    try context.save()
                }
            } catch {
                storedError = error
            }
        }
        if let error = storedError {
            throw error
        }
    }

    func countAll() -> Int {
        var count = 0
        context.performAndWait {
            let request: NSFetchRequest<DCAPlan> = DCAPlan.fetchRequest()
            do {
                count = try context.count(for: request)
            } catch {
                print("Failed to count plans: \(error)")
            }
        }
        return count
    }

    func appendHistoryEntry(planId: UUID, completionDate: Date, note: String?) {
        context.performAndWait {
            let history = PlanReminderHistory(context: context)
            history.id = UUID()
            history.planId = planId
            history.completionDate = completionDate
            history.createdAt = Date()
            history.note = note
            if let plan = fetchPlan(with: planId) {
                plan.lastCompletionDate = completionDate
            }
            do {
                try context.save()
            } catch {
                print("Failed to append plan history: \(error)")
            }
        }
    }

    func fetchHistory(for planId: UUID, limit: Int = 20) -> [PlanHistoryRecord] {
        var records: [PlanHistoryRecord] = []
        context.performAndWait {
            let request: NSFetchRequest<PlanReminderHistory> = PlanReminderHistory.fetchRequest()
            request.predicate = NSPredicate(format: "planId == %@", planId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "completionDate", ascending: false)]
            request.fetchLimit = limit
            do {
                let entries = try context.fetch(request)
                records = entries.compactMap { entry in
                    guard let id = entry.id, let planId = entry.planId,
                        let completionDate = entry.completionDate
                    else {
                        return nil
                    }
                    return PlanHistoryRecord(
                        id: id,
                        planId: planId,
                        completionDate: completionDate,
                        note: entry.note,
                        createdAt: entry.createdAt
                    )
                }
            } catch {
                print("Failed to fetch plan history: \(error)")
            }
        }
        return records
    }

    func replaceNotificationRecords(planId: UUID, records: [PlanNotificationSnapshot]) {
        context.performAndWait {
            let fetch: NSFetchRequest<PlanNotificationRecord> =
                PlanNotificationRecord.fetchRequest()
            fetch.predicate = NSPredicate(format: "planId == %@", planId as CVarArg)
            do {
                let existing = try context.fetch(fetch)
                existing.forEach { context.delete($0) }
                records.forEach { snapshot in
                    let record = PlanNotificationRecord(context: context)
                    record.id = snapshot.id
                    record.planId = planId
                    record.fireDate = snapshot.fireDate
                    record.offsetDays = Int16(snapshot.offsetDays)
                    record.notificationId = snapshot.notificationId
                    record.state = snapshot.state
                }
                try context.save()
            } catch {
                print("Failed to replace notification records: \(error)")
            }
        }
    }

    func fetchNotificationRecords(planId: UUID) -> [PlanNotificationSnapshot] {
        var snapshots: [PlanNotificationSnapshot] = []
        context.performAndWait {
            let request: NSFetchRequest<PlanNotificationRecord> =
                PlanNotificationRecord.fetchRequest()
            request.predicate = NSPredicate(format: "planId == %@", planId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "fireDate", ascending: true)]
            do {
                let records = try context.fetch(request)
                snapshots = records.compactMap { record in
                    guard let id = record.id, let planId = record.planId,
                        let fireDate = record.fireDate, let notificationId = record.notificationId
                    else {
                        return nil
                    }
                    return PlanNotificationSnapshot(
                        id: id,
                        planId: planId,
                        fireDate: fireDate,
                        offsetDays: Int(record.offsetDays),
                        notificationId: notificationId,
                        state: record.state
                    )
                }
            } catch {
                print("Failed to fetch notification records: \(error)")
            }
        }
        return snapshots
    }

    func deleteNotificationRecord(with identifier: String) {
        context.performAndWait {
            let request: NSFetchRequest<PlanNotificationRecord> =
                PlanNotificationRecord.fetchRequest()
            request.predicate = NSPredicate(format: "notificationId == %@", identifier)
            request.fetchLimit = 1
            do {
                if let record = try context.fetch(request).first {
                    context.delete(record)
                    try context.save()
                }
            } catch {
                print("Failed to delete notification record: \(error)")
            }
        }
    }
}

extension PlansRepository {
    fileprivate func normalize(_ plan: DCAPlan) -> Bool {
        var didChange = false
        if plan.id == nil {
            plan.id = UUID()
            didChange = true
        }
        if plan.createdAt == nil {
            plan.createdAt = Date()
            didChange = true
        }
        if plan.updatedAt == nil {
            plan.updatedAt = Date()
            didChange = true
        }
        if plan.title?.isEmpty ?? true {
            plan.title = defaultTitle(for: plan)
            didChange = true
        }
        if plan.assetCode == nil, let asset = plan.asset {
            plan.assetCode = asset
            didChange = true
        }
        if plan.amountValue == nil, let amountTRY = plan.amountTRY {
            plan.amountValue = amountTRY
            didChange = true
        }
        if plan.amountUnit == nil {
            plan.amountUnit = "gram"
            didChange = true
        }
        if plan.reminderOffsets == nil {
            plan.reminderOffsets = reminderArray(from: [-3, -1])
            didChange = true
        }
        if plan.motivationalTone == nil {
            plan.motivationalTone = "coach"
            didChange = true
        }
        if plan.timeZoneIdentifier == nil {
            plan.timeZoneIdentifier = TimeZone.current.identifier
            didChange = true
        }
        if plan.nextDueDate == nil {
            plan.nextDueDate = plan.startDate ?? Date()
            didChange = true
        }
        return didChange
    }

    fileprivate func mapPlanRecord(_ plan: DCAPlan) -> PlanRecord? {
        guard let id = plan.id else { return nil }
        let assetCode =
            AssetCode(rawValue: plan.assetCode ?? plan.asset ?? AssetCode.BTC.rawValue) ?? .BTC
        let frequency =
            DCAFrequency(rawValue: plan.frequency ?? DCAFrequency.monthly.rawValue) ?? .monthly
        let offsets = (plan.reminderOffsets as? [NSNumber])?.map { $0.intValue } ?? []
        let title = plan.title ?? defaultTitle(for: plan)
        return PlanRecord(
            id: id,
            objectID: plan.objectID,
            title: title,
            assetCode: assetCode,
            frequency: frequency,
            amountValue: plan.amountValue?.decimalValue ?? plan.amountTRY?.decimalValue ?? 0,
            amountUnit: plan.amountUnit ?? "gram",
            dayOfMonth: Int(plan.dayOfMonth),
            dayOfWeek: Int(plan.dayOfWeek),
            reminderOffsets: offsets,
            motivationalTone: plan.motivationalTone ?? "coach",
            messageTemplateId: plan.messageTemplateId,
            isActive: plan.isActive,
            startDate: plan.startDate,
            nextDueDate: plan.nextDueDate,
            lastCompletionDate: plan.lastCompletionDate,
            timeZoneIdentifier: plan.timeZoneIdentifier ?? TimeZone.current.identifier,
            createdAt: plan.createdAt,
            updatedAt: plan.updatedAt
        )
    }

    fileprivate func reminderArray(from values: [Int]) -> NSArray {
        values.map { NSNumber(value: $0) } as NSArray
    }

    fileprivate func defaultTitle(for plan: DCAPlan) -> String {
        let assetName = plan.assetCode ?? plan.asset ?? "Plan"
        return "\(assetName.uppercased()) Planı"
    }

    fileprivate func fetchPlan(with id: UUID) -> DCAPlan? {
        let request: NSFetchRequest<DCAPlan> = DCAPlan.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
