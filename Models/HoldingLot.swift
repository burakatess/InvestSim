import Combine
import CoreData
import Foundation

@objc(HoldingLot)
public class HoldingLot: NSManagedObject {

}

extension HoldingLot {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<HoldingLot> {
        return NSFetchRequest<HoldingLot>(entityName: "HoldingLot")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var asset: String?
    @NSManaged public var buyDate: Date?
    @NSManaged public var quantity: NSDecimalNumber?
    @NSManaged public var unitCostTRY: NSDecimalNumber?
    @NSManaged public var totalCostTRY: NSDecimalNumber?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
}

extension HoldingLot: Identifiable {

}
