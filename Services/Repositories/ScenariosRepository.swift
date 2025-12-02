import Foundation
import CoreData

struct ScenarioRecord: Equatable {
    let id: UUID
    let objectID: NSManagedObjectID
    let name: String
    let updatedAt: Date
    let createdAt: Date
    let isActive: Bool
}

final class ScenariosRepository {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func fetchAllRecords() -> [ScenarioRecord] {
        var records: [ScenarioRecord] = []
        context.performAndWait {
            let request: NSFetchRequest<Scenario> = Scenario.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false),
                NSSortDescriptor(key: "name", ascending: true)
            ]
            do {
                let scenarios = try context.fetch(request)
                var needsSave = false
                records = scenarios.map { scenario in
                    if scenario.id == nil {
                        scenario.id = UUID()
                        scenario.createdAt = scenario.createdAt ?? Date()
                        scenario.updatedAt = scenario.updatedAt ?? Date()
                        needsSave = true
                    }
                    return ScenarioRecord(
                        id: scenario.id ?? UUID(),
                        objectID: scenario.objectID,
                        name: scenario.name ?? "Unknown",
                        updatedAt: scenario.updatedAt ?? Date(),
                        createdAt: scenario.createdAt ?? Date(),
                        isActive: scenario.isActive
                    )
                }
                if needsSave {
                    try context.save()
                }
            } catch {
                print("Failed to fetch scenarios: \(error)")
            }
        }
        return records
    }
    
    func add(name: String, paramsJSON: Data) {
        context.performAndWait {
            let scenario = Scenario(context: context)
            scenario.id = UUID()
            scenario.name = name
            scenario.paramsJSON = paramsJSON
            scenario.createdAt = Date()
            scenario.updatedAt = Date()
            scenario.isActive = false
            do {
                try context.save()
            } catch {
                print("Failed to create scenario: \(error)")
            }
        }
    }

    func addScenario(config: ScenarioConfig, result: SimulationResult) {
        context.perform { [context] in
            let scenario = Scenario(context: context)
            scenario.id = UUID()
            let trimmedName = config.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US")
                formatter.dateFormat = "dd MMM yyyy HH:mm"
                scenario.name = "Simülasyon - \(formatter.string(from: Date()))"
            } else {
                scenario.name = trimmedName
            }
            scenario.startDate = config.startDate
            scenario.endDate = config.endDate
            scenario.initialAmount = NSDecimalNumber(decimal: config.initialInvestment)
            scenario.monthlyContribution = NSDecimalNumber(decimal: config.monthlyInvestment)
            scenario.isActive = false
            scenario.createdAt = Date()
            scenario.updatedAt = Date()

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(safeConfig(from: config)) {
                scenario.paramsJSON = data
            }

            let snapshot = ScenarioSnapshot(context: context)
            snapshot.id = UUID()
            snapshot.date = result.simulationDate
            snapshot.totalValue = NSDecimalNumber(decimal: result.currentValueTRY)
            snapshot.totalCost = NSDecimalNumber(decimal: result.investedTotalTRY)
            snapshot.profitLoss = NSDecimalNumber(decimal: result.profitTRY)
            snapshot.profitLossPercentage = NSDecimalNumber(decimal: result.profitPct)
            snapshot.createdAt = Date()
            snapshot.scenario = scenario

            scenario.addToSnapshots(snapshot)

            do {
                try context.save()
                NotificationCenter.default.post(name: .scenarioDidSave, object: nil)
            } catch {
                print("Failed to save scenario result: \(error)")
                context.rollback()
            }
        }
    }

    func touch(objectID: NSManagedObjectID) {
        context.performAndWait { [context] in
            guard let scenario = try? context.existingObject(with: objectID) as? Scenario else { return }
            scenario.updatedAt = Date()
            do {
                try context.save()
            } catch {
                print("Failed to update scenario: \(error)")
            }
        }
    }
}

extension Notification.Name {
    static let scenarioDidSave = Notification.Name("scenarioDidSave")
}

// MARK: - Encoding proxies to avoid MainActor isolated types

private func safeConfig(from config: ScenarioConfig) -> ScenarioConfigSnapshot {
    ScenarioConfigSnapshot(from: config)
}

struct ScenarioConfigSnapshot: Codable {
    let id: UUID
    let name: String
    let initialInvestment: Decimal
    let monthlyInvestment: Decimal
    let investmentCurrency: AssetCode
    let startDate: Date
    let endDate: Date
    let intervalRawValue: Int
    let frequency: Int
    let slippage: Decimal
    let transactionFee: Decimal
    let assetAllocations: [AssetAllocationSnapshot]
    let customDaysOfMonth: [Int]?

    init(from config: ScenarioConfig) {
        id = config.id
        name = config.name
        initialInvestment = config.initialInvestment
        monthlyInvestment = config.monthlyInvestment
        investmentCurrency = config.investmentCurrency
        startDate = config.startDate
        endDate = config.endDate
        intervalRawValue = config.intervalRawValue
        frequency = config.frequency
        slippage = config.slippage
        transactionFee = config.transactionFee
        assetAllocations = config.assetAllocations.map { AssetAllocationSnapshot(allocation: $0) }
        customDaysOfMonth = config.customDaysOfMonth
    }

    func toScenarioConfig() -> ScenarioConfig {
        let interval: Calendar.Component
        switch intervalRawValue {
        case 0: interval = .day
        case 1: interval = .weekOfMonth
        case 2: interval = .month
        default: interval = .month
        }

        let allocations = assetAllocations.map { $0.toAllocation() }

        return ScenarioConfig(
            id: id,
            name: name,
            initialInvestment: initialInvestment,
            monthlyInvestment: monthlyInvestment,
            investmentCurrency: investmentCurrency,
            startDate: startDate,
            endDate: endDate,
            interval: interval,
            frequency: frequency,
            slippage: slippage,
            transactionFee: transactionFee,
            assetAllocations: allocations,
            customDaysOfMonth: customDaysOfMonth
        )
    }
}

struct AssetAllocationSnapshot: Codable {
    let assetCode: AssetCode
    let weight: Decimal
    let isEnabled: Bool

    init(allocation: AssetAllocation) {
        assetCode = allocation.assetCode
        weight = allocation.weight
        isEnabled = allocation.isEnabled
    }

    func toAllocation() -> AssetAllocation {
        AssetAllocation(assetCode: assetCode, weight: weight, isEnabled: isEnabled)
    }
}
