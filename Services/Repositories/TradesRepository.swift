import Combine
import CoreData
import Foundation

final class TradesRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchAll() -> [DCATrade] {
        var trades: [DCATrade] = []
        context.performAndWait {
            let request: NSFetchRequest<DCATrade> = DCATrade.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "tradeDate", ascending: false)
            ]
            do {
                trades = try context.fetch(request)
                trades = ensureIdentity(for: trades)
            } catch {
                print("Core Data fetch error: \(error)")
                trades = []
            }
        }
        return trades
    }

    func fetchForAsset(_ asset: AssetCode) -> [DCATrade] {
        var trades: [DCATrade] = []
        context.performAndWait {
            let request: NSFetchRequest<DCATrade> = DCATrade.fetchRequest()
            request.predicate = NSPredicate(format: "asset == %@", asset.rawValue)
            request.sortDescriptors = [
                NSSortDescriptor(key: "tradeDate", ascending: false)
            ]
            do {
                trades = try context.fetch(request)
                trades = ensureIdentity(for: trades)
            } catch {
                print("Core Data fetch error: \(error)")
                trades = []
            }
        }
        return trades
    }

    func fetch(for asset: AssetCode) -> [DCATrade] {
        return fetchForAsset(asset)
    }

    func replaceDcaTrades(with trades: [DCATrade]) {
        context.performAndWait {
            let request: NSFetchRequest<DCATrade> = DCATrade.fetchRequest()
            request.predicate = NSPredicate(format: "source == %@", TradeSource.dca.rawValue)
            do {
                let existing = try context.fetch(request)
                existing.forEach { context.delete($0) }
            } catch {
                print("Failed to fetch existing DCA trades: \(error)")
            }
            trades.forEach { trade in
                if trade.managedObjectContext == context {
                    trade.source = TradeSource.dca.rawValue
                    trade.createdAt = trade.createdAt ?? Date()
                } else {
                    let copy = DCATrade(context: context)
                    copy.id = trade.id ?? UUID()
                    copy.planId = trade.planId
                    copy.asset = trade.asset
                    copy.quantity = trade.quantity
                    copy.unitPriceTRY = trade.unitPriceTRY
                    copy.totalCostTRY = trade.totalCostTRY
                    copy.tradeDate = trade.tradeDate
                    copy.source = TradeSource.dca.rawValue
                    copy.createdAt = trade.createdAt ?? Date()
                    copy.notes = trade.notes
                }
            }
            saveContext()
        }
    }

    func deleteAll(for asset: AssetCode) {
        context.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "DCATrade")
            request.predicate = NSPredicate(format: "asset == %@", asset.rawValue)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            do {
                try context.execute(deleteRequest)
                try context.save()
            } catch {
                print("Failed to delete trades for asset \(asset): \(error)")
            }
        }
    }

    // MARK: - Helpers
    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Core Data save error: \(error)")
        }
    }

    private func ensureIdentity(for trades: [DCATrade]) -> [DCATrade] {
        var needsSave = false
        trades.forEach { trade in
            if trade.id == nil {
                trade.id = UUID()
                trade.createdAt = trade.createdAt ?? Date()
                needsSave = true
            }
        }
        if needsSave { saveContext() }
        return trades
    }
}
