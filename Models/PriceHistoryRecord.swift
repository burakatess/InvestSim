import Foundation
import CoreData

@objc(PriceHistoryRecord)
public class PriceHistoryRecord: NSManagedObject {}

extension PriceHistoryRecord {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PriceHistoryRecord> {
        NSFetchRequest<PriceHistoryRecord>(entityName: "PriceHistoryRecord")
    }
    
    @NSManaged public var assetCode: String
    @NSManaged public var date: Date
    @NSManaged public var price: Double
}
