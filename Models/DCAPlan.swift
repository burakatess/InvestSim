import Foundation
import CoreData

@objc(DCAPlan)
public class DCAPlan: NSManagedObject {
    var reminderOffsetsValue: [Int] {
        (reminderOffsets as? [NSNumber])?.map { $0.intValue } ?? []
    }
    
    var primaryAssetCode: AssetCode {
        AssetCode(assetCode ?? asset ?? "USD")
    }
    
    var resolvedAmount: Decimal {
        if let amountValue = amountValue {
            return amountValue.decimalValue
        }
        if let amountTRY = amountTRY {
            return amountTRY.decimalValue
        }
        return 0
    }
}

extension DCAPlan {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DCAPlan> {
        return NSFetchRequest<DCAPlan>(entityName: "DCAPlan")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var asset: String?
    @NSManaged public var assetCode: String?
    @NSManaged public var frequency: String?
    @NSManaged public var amountTRY: NSDecimalNumber?
    @NSManaged public var amountValue: NSDecimalNumber?
    @NSManaged public var amountUnit: String?
    @NSManaged public var dayOfMonth: Int16
    @NSManaged public var dayOfWeek: Int16
    @NSManaged public var isActive: Bool
    @NSManaged public var startDate: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var reminderOffsets: NSObject?
    @NSManaged public var motivationalTone: String?
    @NSManaged public var messageTemplateId: String?
    @NSManaged public var nextDueDate: Date?
    @NSManaged public var lastCompletionDate: Date?
    @NSManaged public var timeZoneIdentifier: String?
}

extension DCAPlan: Identifiable {}
