//
//  CoreDataManager.swift
//  CoreDataManager
//
//  Created by Guillem Espejo on 22/03/2020.
//  Copyright © 2020 GuillemEspejo. All rights reserved.
//

import CoreData

// Base code from this URL
// http://williamboles.me/step-by-step-core-data-migration/  In case of needing manual migrations, this post seems quite interesting
// En este repo esta el codigo completo usado en esta clase mas un sistema de migracion semi-automatico que he de mirar
// https://github.com/wibosco/CoreDataMigrationRevised-Example
// La info referente a esto esta aqui:
// https://williamboles.me/progressive-core-data-migration/




// Otra version aqui:
// Este tio menciona que es su solucion "tras mirar mucha documentacion outdated y liosa" y haberse aclarado un poco
// https://medium.com/@duncsand/threading-43a9081284e5
//
// Si lo de arriba no termina de convencerme, echar un vistazo a esto:
// https://www.raywenderlich.com/7586-multiple-managed-object-contexts-with-core-data-tutorial



// Info sobre la manera "chachi" de hacerlo.
//https://stackoverflow.com/questions/42733574/nspersistentcontainer-concurrency-for-saving-to-core-data


// Otra manera chula: https://samwize.com/2018/09/01/modern-guide-to-core-data-2018/

// ULTIMO VISTAZO, EMPEZAR POR AQUI:  https://medium.com/@aliakhtar_16369/mastering-in-coredata-part-3-coding-crud-in-core-data-b7a278436c3

public final class CoreDataManager : CustomStringConvertible{
    
    public static let shared = CoreDataManager()
    
    private var setupWasCalled = false
    private var modelName : String!
    private let persistentContainerQueue : OperationQueue
    
    // ------------------------------------------------------------
    // PROPERTIES
    // ------------------------------------------------------------
    // MARK: - Properties
    lazy var persistentContainer: NSPersistentContainer! = {
        let persistentContainer = NSPersistentContainer(name: self.modelName )
        return persistentContainer
    }()
    
    // Concurrencytype =  NSPrivateQueueConcurrencyType
    lazy var backgroundContext: NSManagedObjectContext = {
        let context = self.persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }()
    
    // ConcurrencyType = NSMainQueueConcurrencyType
    // Solo puede ser usado con la main queue de la app (main thread?)
    // Hacer siempre los fetch via este context
    lazy var mainContext: NSManagedObjectContext = {
        let context = self.persistentContainer.viewContext
        context.shouldDeleteInaccessibleFaults = true
        return context
    }()

    
    // ------------------------------------------------------------
    // INIT-DEINIT
    // ------------------------------------------------------------
    // MARK: - Init-Deinit
    private init(){
        self.persistentContainerQueue = OperationQueue()
        self.persistentContainerQueue.maxConcurrentOperationCount = 1
    }
    
    deinit{
        do {
            try self.mainContext.save()
        } catch {
            fatalError("CoreDataManager ERROR Deinit: \(error))")
        }
    }
    
    // ------------------------------------------------------------
    // SETUP
    // ------------------------------------------------------------
    // MARK: - Setup
    /// Asynchronously initializes CoreDataManager stack. Must be called before doing any other operation related to Core Data.
    /// - Parameter name: Core Data model filename.
    /// - Parameter completion: A completion block that will be executed whenever the setup process succeeds.
    public func setup(withModel name:String, completion: @escaping () -> Void) {
        self.setupWasCalled = true
        self.modelName = name
        
        guard Bundle.main.url(forResource: self.modelName, withExtension: "momd") != nil else{
            fatalError("CoreDataManager ERROR Loading: Model file named '\(name)' not found.")
        }
        
        self.persistentContainer.loadPersistentStores { description, error in
            guard error == nil else {
                fatalError("CoreDataManager ERROR Loading: \(error!)")
            }
            completion()
        }
    }
    
    // ------------------------------------------------------------
    // CRUD OPERATIONS
    // ------------------------------------------------------------
    // MARK: - CRUD Operations
   
    // ------------------------------------------------------------
    // CREATE
    
    /*
    
    DB.default.container.performBackgroundTask { context in
        let note = Note(context: context)
        note.content = "Hello World"
        note.priority = 99
        try! context.save()
    }
    */
    
    
    public func saveContext() -> Bool{
        guard setupWasCalled == true else{
            print("CoreDataManager ERROR: Setup method wasn't called, persistentStores may not be loaded.")
            return false
        }
        
        let context = self.mainContext
        if context.hasChanges {
            do {
                try context.save()
                return true

            } catch {
                print("CoreDataManager ERROR Saving: \(error)")
                return false
            }
        }
        return false
        
        
        /*
        
        
        container.performBackgroundTask { (context) in
         for _ in 0…100000 {
             let user = User(context: context)
             user.name = name
             user.lastName = lastName
         }
         do {
             try context.save()
             print(“Usuario \(name) guardado”)
             //2
             DispatchQueue.main.async {
                 completion()
             }
          } catch {
            print(“Error guardando usuario — \(error)”)
          }
        } // fin del performBackgroundTask
     */
    }
    
    // ------------------------------------------------------------
    // READ
    public func executeFetch(request: NSFetchRequest<NSFetchRequestResult>) -> [Any] {
        do{
            return try mainContext.fetch(request)
        }catch{
            print("CoreDataManager ERROR Fetching: \(error)")
        }
        
        return [Any]()
    }

    
    // ------------------------------------------------------------
    // UPDATE
    
    
    
    // ------------------------------------------------------------
    // DELETE
    
    /// Deletes all `NSManagedObject` entities selected by a `NSFetchRequest`.
    /// - Parameter request: The `NSFetchRequest` to use as an entity selector.
    public func delete(entitiesFrom request:NSFetchRequest<NSFetchRequestResult>) {
        enqueue { (bgrContext) in
            let deleteBatch = NSBatchDeleteRequest(fetchRequest: request)
            deleteBatch.resultType = .resultTypeObjectIDs
            do{
                try bgrContext.execute(deleteBatch)
                
            }catch{
                print("CoreDataManager ERROR Removing: \(error)")
            }
        }
    }
    
    // ------------------------------------------------------------
    // MISC
    // ------------------------------------------------------------
    // MARK: - Misc
    
    /// Cleans main context, refreshing all loaded objects from Core Data and reseting the context. This allows to remove
    /// current in-memory unused `NSManagedObject`. Useful after importing or creating large ammounts of data.
    ///
    /// - Parameter name: The `Entity` name to remove.
    /// - Returns: A boolean representing operation success.
    public func cleanMainContext(){
        let context = self.persistentContainer.viewContext
        for object in context.registeredObjects {
            context.refresh(object, mergeChanges: false)
        }
        
        context.reset()
    }
    
    // From CustomStringConvertible
    public var description: String {
        "\(CoreDataManager.self): Context=\(mainContext); BgrContext=\(backgroundContext))"
    }
    
    // ------------------------------------------------------------
    // PRIVATE METHODS
    // ------------------------------------------------------------
    // MARK: - Private methods
    // En estos dos aparecen los comentarios que dan lugar a este metodo. Echar un vistazo para dar con el funcionamiento "general"
   // de todo esto...
   // https://stackoverflow.com/questions/51014065/whats-the-best-practice-for-nspersistentcontainer-newbackgroundcontext
   // https://stackoverflow.com/questions/42733574/nspersistentcontainer-concurrency-for-saving-to-core-data
    private func enqueue(block: @escaping (_ context: NSManagedObjectContext) -> Void) {
        persistentContainerQueue.addOperation(){
            self.backgroundContext.performAndWait{
                block(self.backgroundContext)
                try? self.backgroundContext.save() //Don't just use '?' here look at the error and log it to your analytics service
            }
        }
    }
}






/// Removes all `NSManagedObject` entities selected by a `NSFetchRequest`.
///
/// - Parameter request: The `NSFetchRequest` to use as an entity selector.
/// - Returns: A boolean representing operation success.
/*
public func remove(entitiesFrom request:NSFetchRequest<NSFetchRequestResult>) -> Bool{
     let deleteBatch = NSBatchDeleteRequest(fetchRequest: request)
     deleteBatch.resultType = .resultTypeObjectIDs
    
     do {
         let result = try backgroundContext.execute(deleteBatch) as? NSBatchDeleteResult
         let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: result?.result as? [NSManagedObjectID] ?? []]
         NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [mainContext])
         return true

    }catch {
        print("CoreDataManager ERROR Removing: \(error)")
        return false
    }
}
*/
