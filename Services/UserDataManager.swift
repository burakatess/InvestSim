import Foundation
import CoreData
import Combine

// MARK: - User Data Manager
@MainActor
final class UserDataManager: ObservableObject {
    static let shared = UserDataManager()
    
    @Published var currentUserId: String?
    @Published var isDataIsolated: Bool = true
    
    private let coreDataStack: CoreDataStack
    private let userDefaults = UserDefaults.standard
    private let currentUserIdKey = "currentUserId"
    
    private init() {
        self.coreDataStack = CoreDataStack.shared
        self.currentUserId = userDefaults.string(forKey: currentUserIdKey)
    }
    
    // MARK: - User Switching
    
    func switchUser(userId: String) {
        currentUserId = userId
        userDefaults.set(userId, forKey: currentUserIdKey)
        isDataIsolated = true
        objectWillChange.send()
    }
    
    func clearCurrentUser() {
        currentUserId = nil
        userDefaults.removeObject(forKey: currentUserIdKey)
        isDataIsolated = false
        objectWillChange.send()
    }
    
    // MARK: - Data Isolation Helpers
    
    func createUserPredicate() -> NSPredicate {
        guard let userId = currentUserId else {
            return NSPredicate(value: false) // No data if no user
        }
        return NSPredicate(format: "userId == %@", userId)
    }
    
    func createUserPredicate(for entityName: String) -> NSPredicate {
        guard let userId = currentUserId else {
            return NSPredicate(value: false)
        }
        return NSPredicate(format: "userId == %@", userId)
    }
    
    // MARK: - Guest Data Management
    
    func migrateGuestDataToUser(guestUserId: String, newUserId: String) {
        let context = coreDataStack.viewContext
        
        // Get all guest data
        let guestPredicate = NSPredicate(format: "userId == %@", guestUserId)
        
        // Update all entities with new userId
        let entityNames = ["Asset", "Trade", "Portfolio", "DCAPlan", "Scenario"]
        
        for entityName in entityNames {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.predicate = guestPredicate
            
            do {
                let objects = try context.fetch(request)
                for object in objects {
                    object.setValue(newUserId, forKey: "userId")
                }
            } catch {
                print("Error migrating \(entityName): \(error)")
            }
        }
        
        // Save changes
        do {
            try context.save()
            print("Successfully migrated guest data to user: \(newUserId)")
        } catch {
            print("Error saving migrated data: \(error)")
        }
    }
    
    func clearGuestData(guestUserId: String) {
        let context = coreDataStack.viewContext
        let guestPredicate = NSPredicate(format: "userId == %@", guestUserId)
        
        let entityNames = ["Asset", "Trade", "Portfolio", "DCAPlan", "Scenario"]
        
        for entityName in entityNames {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            request.predicate = guestPredicate
            
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            
            do {
                try context.execute(deleteRequest)
                print("Cleared guest data for \(entityName)")
            } catch {
                print("Error clearing guest data for \(entityName): \(error)")
            }
        }
        
        // Save changes
        do {
            try context.save()
            print("Successfully cleared guest data")
        } catch {
            print("Error saving after clearing guest data: \(error)")
        }
    }
    
    // MARK: - Data Validation
    
    func validateUserData(userId: String) -> Bool {
        let context = coreDataStack.viewContext
        let predicate = NSPredicate(format: "userId == %@", userId)
        
        let entityNames = ["Asset", "Trade", "Portfolio", "DCAPlan", "Scenario"]
        
        for entityName in entityNames {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.predicate = predicate
            request.fetchLimit = 1
            
            do {
                let count = try context.count(for: request)
                if count > 0 {
                    return true // User has data
                }
            } catch {
                print("Error validating data for \(entityName): \(error)")
            }
        }
        
        return false // No data found
    }
    
    // MARK: - Statistics
    
    func getUserDataCount(userId: String) -> UserDataCount {
        let context = coreDataStack.viewContext
        let predicate = NSPredicate(format: "userId == %@", userId)
        
        var count = UserDataCount()
        
        // Count Assets
        let assetRequest = NSFetchRequest<NSManagedObject>(entityName: "Asset")
        assetRequest.predicate = predicate
        count.assets = (try? context.count(for: assetRequest)) ?? 0
        
        // Count Trades
        let tradeRequest = NSFetchRequest<NSManagedObject>(entityName: "Trade")
        tradeRequest.predicate = predicate
        count.trades = (try? context.count(for: tradeRequest)) ?? 0
        
        // Count Portfolios
        let portfolioRequest = NSFetchRequest<NSManagedObject>(entityName: "Portfolio")
        portfolioRequest.predicate = predicate
        count.portfolios = (try? context.count(for: portfolioRequest)) ?? 0
        
        // Count DCA Plans
        let dcaRequest = NSFetchRequest<NSManagedObject>(entityName: "DCAPlan")
        dcaRequest.predicate = predicate
        count.dcaPlans = (try? context.count(for: dcaRequest)) ?? 0
        
        // Count Scenarios
        let scenarioRequest = NSFetchRequest<NSManagedObject>(entityName: "Scenario")
        scenarioRequest.predicate = predicate
        count.scenarios = (try? context.count(for: scenarioRequest)) ?? 0
        
        return count
    }
}

// MARK: - User Data Count
struct UserDataCount {
    var assets: Int = 0
    var trades: Int = 0
    var portfolios: Int = 0
    var dcaPlans: Int = 0
    var scenarios: Int = 0
    
    var total: Int {
        assets + trades + portfolios + dcaPlans + scenarios
    }
    
    var isEmpty: Bool {
        total == 0
    }
}
