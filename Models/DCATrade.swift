import Combine
import CoreData
import Foundation

@objc(DCATrade)
public class DCATrade: NSManagedObject {

}

extension DCATrade {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DCATrade> {
        return NSFetchRequest<DCATrade>(entityName: "DCATrade")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var planId: UUID?
    @NSManaged public var asset: String?
    @NSManaged public var quantity: NSDecimalNumber?
    @NSManaged public var unitPriceTRY: NSDecimalNumber?
    @NSManaged public var totalCostTRY: NSDecimalNumber?
    @NSManaged public var tradeDate: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var source: String?
    @NSManaged public var notes: String?
}

extension DCATrade: Identifiable {

}
