import Combine
import CoreData
import Foundation

@objc(PlanReminderHistory)
public class PlanReminderHistory: NSManagedObject {}

extension PlanReminderHistory {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlanReminderHistory> {
        NSFetchRequest<PlanReminderHistory>(entityName: "PlanReminderHistory")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var planId: UUID?
    @NSManaged public var completionDate: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var note: String?
}

extension PlanReminderHistory: Identifiable {}

@objc(PlanNotificationRecord)
public class PlanNotificationRecord: NSManagedObject {}

extension PlanNotificationRecord {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlanNotificationRecord> {
        NSFetchRequest<PlanNotificationRecord>(entityName: "PlanNotificationRecord")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var planId: UUID?
    @NSManaged public var fireDate: Date?
    @NSManaged public var offsetDays: Int16
    @NSManaged public var notificationId: String?
    @NSManaged public var state: String?
}

extension PlanNotificationRecord: Identifiable {}
