import Combine
import CoreData
import Foundation

struct AssetDTO {
    let code: String
    let displayName: String
    let symbol: String?
    let category: String
    let currency: String
    let logoURL: String?
    let isActive: Bool
    let providerType: AssetProviderType
    let externalId: String?
    let coingeckoId: String?
}

@MainActor
final class AssetRepository: ObservableObject {
    @Published private(set) var activeAssets: [AssetDefinition] = []

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        loadActiveAssets()
    }

    func fetchAllActive() -> [AssetDefinition] {
        activeAssets
    }

    func fetch(byCode code: String) -> AssetDefinition? {
        activeAssets.first { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }

    @discardableResult
    func addOrUpdate(from dto: AssetDTO) -> AssetDefinition {
        let normalizedCode = dto.code.uppercased()
        let fetch: NSFetchRequest<AssetDefinition> = AssetDefinition.fetchRequest()
        fetch.predicate = NSPredicate(format: "code ==[c] %@", normalizedCode)
        fetch.fetchLimit = 1
        let definition = (try? context.fetch(fetch).first) ?? AssetDefinition(context: context)
        if definition.id == nil {
            definition.id = UUID()
            definition.createdAt = Date()
        }
        definition.code = normalizedCode
        definition.displayName = dto.displayName
        definition.symbol = dto.symbol ?? normalizedCode
        definition.category = dto.category.lowercased()
        definition.currency = dto.currency.uppercased()
        definition.logoURL = dto.logoURL
        definition.externalId = dto.externalId
        definition.coingeckoId = dto.coingeckoId
        definition.providerType = dto.providerType.rawValue
        definition.isActive = dto.isActive
        try? context.save()
        loadActiveAssets()
        return definition
    }

    func deactivate(code: String) {
        let fetch: NSFetchRequest<AssetDefinition> = AssetDefinition.fetchRequest()
        fetch.predicate = NSPredicate(format: "code ==[c] %@", code)
        fetch.fetchLimit = 1
        guard let definition = try? context.fetch(fetch).first else { return }
        definition.isActive = false
        try? context.save()
        loadActiveAssets()
    }

    func reload() {
        loadActiveAssets()
    }

    private func loadActiveAssets() {
        let request: NSFetchRequest<AssetDefinition> = AssetDefinition.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "displayName", ascending: true)]
        do {
            activeAssets = try context.fetch(request)
            // Only log on significant changes
            if activeAssets.count != (activeAssets.count) {
                print("📊 AssetRepository loaded \(activeAssets.count) active assets")
            }
        } catch {
            print("❌ AssetRepository failed to load assets: \(error)")
            activeAssets = []
        }
    }
}
