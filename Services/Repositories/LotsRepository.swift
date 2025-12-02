import Combine
import CoreData
import Foundation

final class LotsRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchAll() -> [HoldingLot] {
        let request: NSFetchRequest<HoldingLot> = HoldingLot.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "buyDate", ascending: false)
        ]
        let lots = performFetch(request)
        return ensureIdentity(for: lots)
    }

    func fetchForAsset(_ asset: AssetCode) -> [HoldingLot] {
        let request: NSFetchRequest<HoldingLot> = HoldingLot.fetchRequest()
        request.predicate = NSPredicate(format: "asset == %@", asset.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(key: "buyDate", ascending: false)
        ]
        let lots = performFetch(request)
        return ensureIdentity(for: lots)
    }

    func fetch(for asset: AssetCode) -> [HoldingLot] {
        return fetchForAsset(asset)
    }

    func replaceAll(with lots: [HoldingLot]) {
        let request: NSFetchRequest<NSFetchRequestResult> = HoldingLot.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Failed to clear lots: \(error)")
        }
        lots.forEach { lot in
            if lot.managedObjectContext == context {
                lot.createdAt = lot.createdAt ?? Date()
                lot.updatedAt = Date()
            } else {
                let copy = HoldingLot(context: context)
                copy.id = lot.id ?? UUID()
                copy.asset = lot.asset
                copy.buyDate = lot.buyDate
                copy.quantity = lot.quantity
                copy.unitCostTRY = lot.unitCostTRY
                copy.totalCostTRY = lot.totalCostTRY
                copy.createdAt = lot.createdAt ?? Date()
                copy.updatedAt = lot.updatedAt ?? Date()
            }
        }
        saveContext()
    }

    func add(_ lot: HoldingLot) {
        if lot.id == nil { lot.id = UUID() }
        if lot.createdAt == nil { lot.createdAt = Date() }
        lot.updatedAt = Date()
        saveContext()
    }

    func deleteAll(for asset: AssetCode) {
        context.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "HoldingLot")
            request.predicate = NSPredicate(format: "asset == %@", asset.rawValue)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            do {
                try context.execute(deleteRequest)
                try context.save()
            } catch {
                print("Failed to delete lots for asset \(asset): \(error)")
            }
        }
    }

    func create(asset: AssetCode, buyDate: Date, quantity: Decimal, unitCostTRY: Decimal)
        -> HoldingLot
    {
        let lot = HoldingLot(context: context)
        lot.id = UUID()
        lot.asset = asset.rawValue
        lot.buyDate = buyDate
        lot.quantity = NSDecimalNumber(decimal: quantity)
        lot.unitCostTRY = NSDecimalNumber(decimal: unitCostTRY)
        let totalCost = MoneyPrecisionHelper.multiply(quantity, unitCostTRY)
        lot.totalCostTRY = NSDecimalNumber(decimal: totalCost)
        lot.createdAt = Date()
        lot.updatedAt = Date()
        saveContext()
        return lot
    }

    func countAll() -> Int {
        var result = 0
        context.performAndWait {
            let request: NSFetchRequest<HoldingLot> = HoldingLot.fetchRequest()
            do {
                result = try context.count(for: request)
            } catch {
                print("Failed to count lots: \(error)")
            }
        }
        return result
    }

    // MARK: - Helpers
    private func performFetch<T: NSFetchRequestResult>(_ request: NSFetchRequest<T>) -> [T] {
        do {
            return try context.fetch(request)
        } catch {
            print("Core Data fetch error: \(error)")
            return []
        }
    }

    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Core Data save error: \(error)")
        }
    }

    private func ensureIdentity(for lots: [HoldingLot]) -> [HoldingLot] {
        var needsSave = false
        lots.forEach { lot in
            if lot.id == nil {
                lot.id = UUID()
                lot.createdAt = lot.createdAt ?? Date()
                lot.updatedAt = lot.updatedAt ?? Date()
                needsSave = true
            }
        }
        if needsSave { saveContext() }
        return lots
    }
}
