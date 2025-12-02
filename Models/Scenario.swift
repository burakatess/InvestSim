import Foundation
import CoreData

@objc(Scenario)
public class Scenario: NSManagedObject {
    
}

extension Scenario {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Scenario> {
        return NSFetchRequest<Scenario>(entityName: "Scenario")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var descriptionText: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var initialAmount: NSDecimalNumber?
    @NSManaged public var monthlyContribution: NSDecimalNumber?
    @NSManaged public var isActive: Bool
    @NSManaged public var paramsJSON: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var snapshots: NSSet?
}

extension Scenario: Identifiable {
    
}

// MARK: Generated accessors for snapshots
extension Scenario {
    @objc(addSnapshotsObject:)
    @NSManaged public func addToSnapshots(_ value: ScenarioSnapshot)
    
    @objc(removeSnapshotsObject:)
    @NSManaged public func removeFromSnapshots(_ value: ScenarioSnapshot)
    
    @objc(addSnapshots:)
    @NSManaged public func addToSnapshots(_ values: NSSet)
    
    @objc(removeSnapshots:)
    @NSManaged public func removeFromSnapshots(_ values: NSSet)
}
