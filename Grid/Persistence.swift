//
//  Persistence.swift
//  Grid
//
//  Created by AJ Picard on 7/31/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data
        let sampleSpace = Space(context: viewContext)
        sampleSpace.id = UUID()
        sampleSpace.name = "Sample Family"
        sampleSpace.createdAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Preview error: \(error)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "GridModel")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data error: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}