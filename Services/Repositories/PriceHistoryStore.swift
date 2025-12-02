import CoreData
import Foundation

final class PriceHistoryStore {
    private let container: NSPersistentContainer

    init(container: NSPersistentContainer) {
        self.container = container
    }

    func saveBulk(assetCode: String, candles: [HistoricalPrice]) async throws {
        guard !candles.isEmpty else { return }
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        try await context.perform {
            for candle in candles {
                let request = PriceHistoryRecord.fetchRequest()
                request.predicate = NSPredicate(
                    format: "assetCode == %@ AND date == %@",
                    assetCode, candle.date as NSDate
                )
                request.fetchLimit = 1
                let record = try context.fetch(request).first ?? PriceHistoryRecord(context: context)
                record.assetCode = assetCode
                record.date = candle.date
                record.price = candle.close
            }
            if context.hasChanges {
                try context.save()
            }
        }
    }

    func fetch(assetCode: String, start: Date, end: Date) async throws -> [HistoricalPrice] {
        let context = container.viewContext
        return try await context.perform {
            let request = PriceHistoryRecord.fetchRequest()
            request.predicate = NSPredicate(
                format: "assetCode == %@ AND date >= %@ AND date <= %@",
                assetCode, start as NSDate, end as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            let records = try context.fetch(request)
            return records.map { HistoricalPrice(date: $0.date, close: $0.price) }
        }
    }
}
