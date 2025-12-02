import Foundation
import CoreData

@objc(ScenarioSnapshot)
public class ScenarioSnapshot: NSManagedObject {
    
}

extension ScenarioSnapshot {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ScenarioSnapshot> {
        return NSFetchRequest<ScenarioSnapshot>(entityName: "ScenarioSnapshot")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var totalValue: NSDecimalNumber?
    @NSManaged public var totalCost: NSDecimalNumber?
    @NSManaged public var profitLoss: NSDecimalNumber?
    @NSManaged public var profitLossPercentage: NSDecimalNumber?
    @NSManaged public var createdAt: Date?
    @NSManaged public var scenario: Scenario?
}

extension ScenarioSnapshot: Identifiable {
    
}
