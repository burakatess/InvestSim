import Combine
import CoreData
import Foundation
import SwiftUI

final class CoreDataStack {
    static let shared = CoreDataStack()

    var persistentContainer: NSPersistentContainer

    private init() {
        // Core Data model dosyası olmadığı için geçici olarak in-memory store kullan
        self.persistentContainer = NSPersistentContainer(name: "InvestSimModel")

        // In-memory store kullan (crash'i önlemek için)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]

        persistentContainer.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("Core Data warning: \(error), \(error.userInfo)")
                // Crash yerine warning yap
            }
        }

        // ViewContext'i main queue'da çalıştır
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    func save() {
        guard viewContext.hasChanges else { return }

        do {
            try viewContext.save()
        } catch {
            print("Core Data save error: \(error)")
        }
    }
}
