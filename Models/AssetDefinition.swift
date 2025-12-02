import CoreData
import Foundation

@objc(AssetDefinition)
public class AssetDefinition: NSManagedObject {}

extension AssetDefinition {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AssetDefinition> {
        NSFetchRequest<AssetDefinition>(entityName: "AssetDefinition")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var code: String
    @NSManaged public var displayName: String
    @NSManaged public var symbol: String?
    @NSManaged public var category: String
    @NSManaged public var currency: String
    @NSManaged public var logoURL: String?
    @NSManaged public var externalId: String?
    @NSManaged public var coingeckoId: String?
    @NSManaged public var providerType: String?
    @NSManaged public var isActive: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var marketCapRank: Int32
    @NSManaged public var yahooSymbol: String?
    @NSManaged public var tefasCode: String?
    @NSManaged public var lastSyncDate: Date?
    @NSManaged public var metadata: Data?
}

extension AssetDefinition: Identifiable {}

extension AssetDefinition {
    var provider: AssetProviderType {
        AssetProviderType(rawValue: providerType ?? AssetProviderType.unknown.rawValue) ?? .unknown
    }
}
