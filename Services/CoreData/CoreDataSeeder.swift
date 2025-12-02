import Foundation
import CoreData

@MainActor
final class CoreDataSeeder {
    private let context: NSManagedObjectContext
    private let assetRepository: AssetRepository
    
    init(context: NSManagedObjectContext, assetRepository: AssetRepository) {
        self.context = context
        self.assetRepository = assetRepository
    }
    
    func seedAssetsIfNeeded(force: Bool = false) {
        let request: NSFetchRequest<AssetDefinition> = AssetDefinition.fetchRequest()
        let count = (try? context.count(for: request)) ?? 0
        if !force && count > 0 { return }
        importDefaultAssets()
    }
    
    func importDefaultAssets() {
        let defaults: [AssetDTO] = AssetDefaults.all.map {
            AssetDTO(
                code: $0.code,
                displayName: $0.displayName,
                symbol: $0.symbol,
                category: $0.category,
                currency: $0.currency,
                logoURL: $0.logoURL,
                isActive: $0.isActive,
                providerType: $0.providerType,
                externalId: $0.externalId,
                coingeckoId: $0.coingeckoId
            )
        }
        defaults.forEach { assetRepository.addOrUpdate(from: $0) }
    }
}
