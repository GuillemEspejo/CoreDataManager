//
//  CoreDataManager.swift
//  CoreDataManager
//
//  Created by Guillem Espejo on 22/03/2020.
//  Copyright © 2020 GuillemEspejo. All rights reserved.
//

import CoreData

public final class CoreDataManager {

    public static let shared = CoreDataManager()
    
    private var setupWasCalled = false
    private var modelName : String!

    
    // ------------------------------------------------------------
    // PROPERTIES
    // ------------------------------------------------------------
    // MARK: - Properties
    lazy var persistentContainer: NSPersistentContainer! = {
        let persistentContainer = NSPersistentContainer(name: self.modelName )
        return persistentContainer
    }()
    
    public lazy var backgroundContext: NSManagedObjectContext = {
        let context = self.persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }()
    
    public lazy var mainContext: NSManagedObjectContext = {
        let context = self.persistentContainer.viewContext
        context.shouldDeleteInaccessibleFaults = true
        context.automaticallyMergesChangesFromParent = true
        return context
    }()

    
    // ------------------------------------------------------------
    // INIT-DEINIT
    // ------------------------------------------------------------
    // MARK: - Init-Deinit
    private init(){
        //self.persistentContainerQueue = OperationQueue()
        //self.persistentContainerQueue.maxConcurrentOperationCount = 1
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
    public func setup(withModel name:String, completion: @escaping () -> Void, error: @escaping (_ error:Error?) -> Void) {
        self.setupWasCalled = true
        self.modelName = name
        
        guard Bundle.main.url(forResource: self.modelName, withExtension: "momd") != nil else{
            print("CoreDataManager ERROR Loading: Model file named '\(name)' not found.")
            error(CoreDataManagerError.modelNotFound)
            return
        }

        self.persistentContainer.loadPersistentStores { description, cderror in
            guard cderror == nil else {
                print("CoreDataManager ERROR Loading: \(cderror!)")
                error(cderror)
                return
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
    public func create(withBlock block: @escaping (_ context:NSManagedObjectContext) -> Void , error: @escaping (_ error:Error?) -> Void){
        guard setupWasCalled == true else{
            print("CoreDataManager ERROR: Setup method wasn't called, persistentStores may not be loaded.")
            error(CoreDataManagerError.setupNotCalled)
            return
        }
        
        print("CREATING IN CORE DATA")
        // Creates a task with a new background context created on the fly
        persistentContainer.performBackgroundTask { context in
            
            block(context)

            do {
                print("SAVING IN CORE DATA")
                // Saves the entries created in the `forEach`
                try context.save()
                print("SAVED IN CORE DATA")
                
            } catch let saveError{
                error(saveError)
                fatalError("Failure to save context: \(saveError)")
            }
        }
        
    }
    
    // ------------------------------------------------------------
    // READ
    /*
    /// Synchronously executes a fetch request.
    /// - Parameter request: The `NSFetchRequest` to use as an entity selector.
    /// - Returns: An array containing the `NSManagedObject` list resulting from the fetch request.
    public func fetchObjects(from request: NSFetchRequest<NSFetchRequestResult>) -> [NSManagedObject] {
        do{
            guard let result = try mainContext.fetch(request) as? [NSManagedObject] else {
                print("CoreDataManager ERROR Async Fetching: Result can't be casted to NSManagedObject")
                return []
            }
            return result
            
        }catch{
            print("CoreDataManager ERROR Fetching: \(error)")
        }
        
        return []
    }
    */

    /// Asynchronously executes a fetch request.
    /// - Parameter request: The `NSFetchRequest` to use as an entity selector.
    /// - Parameter completion: A completion block that will be called in the main thread, with the results assigned.
    public func fetchObjectsAsync(from request: NSFetchRequest<NSFetchRequestResult>, completion: @escaping (_ result:[NSManagedObject]) -> Void){
        guard setupWasCalled == true else{
            print("CoreDataManager ERROR: Setup method wasn't called, persistentStores may not be loaded.")
            return
        }
        
        // Creates `asynchronousFetchRequest` with the fetch request and the completion closure
        let asynchronousFetchRequest = NSAsynchronousFetchRequest(fetchRequest: request) { asynchronousFetchResult in
 
            guard let result = asynchronousFetchResult.finalResult as? [NSManagedObject] else {
                print("CoreDataManager ERROR Async Fetching: Result can't be casted to NSManagedObject")
                return
            }
            print("THREAD ASYNCREQUEST: \(Thread.current)")
            // We refetch objects from its ObjectID in the main queue
            DispatchQueue.main.async {
                var objectList = [NSManagedObject]()
                for item in result {
                    let itemID = item.objectID
                    let queueSafeItem = self.mainContext.object(with: itemID)
                    objectList.append(queueSafeItem)
                }
                completion(objectList)
            }
        }
        print("THREAD: \(Thread.current)")
        do {
            try backgroundContext.execute(asynchronousFetchRequest)
        } catch {
            print("CoreDataManager ERROR Async Fetching: \(error)")
        }
        
    }
    
    // ------------------------------------------------------------
    // UPDATE
    
    public func updateObjetsAsync(){
        guard setupWasCalled == true else{
            print("CoreDataManager ERROR: Setup method wasn't called, persistentStores may not be loaded.")
            return
        }
        
        persistentContainer.performBackgroundTask { privateManagedObjectContext in
            // Creates new batch update request for entity `Dog`
            let updateRequest = NSBatchUpdateRequest(entityName: "TodoTask")
            // All the dogs with `isFavorite` true
            let predicate = NSPredicate(format: "done == true")
            // Assigns the predicate to the batch update
            updateRequest.predicate = predicate

            // Dictionary with the property names to update as keys and the new values as values
            updateRequest.propertiesToUpdate = ["isFavorite": false]

            // Sets the result type as array of object IDs updated
            updateRequest.resultType = .updatedObjectIDsResultType

            do {
                // Executes batch
                let result = try privateManagedObjectContext.execute(updateRequest) as? NSBatchUpdateResult

                // Retrieves the IDs deleted
                guard let objectIDs = result?.result as? [NSManagedObjectID] else {
                    print("CoreDataManager ERROR Removing: Objects retreived are not IDs")
                    return
                }

                // Updates the main context
                let changes = [NSUpdatedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.mainContext])
                
            } catch {
                fatalError("Failed to execute request: \(error)")
            }
        }
    }
    
    
    
    // ------------------------------------------------------------
    // DELETE
    
    /// Deletes all `NSManagedObject` entities selected by a `NSFetchRequest`.
    /// - Parameter request: The `NSFetchRequest` to use as an entity selector.
    public func deleteObjects(from request:NSFetchRequest<NSFetchRequestResult>) {
        guard setupWasCalled == true else{
            print("CoreDataManager ERROR: Setup method wasn't called, persistentStores may not be loaded.")
            return
        }
        
        print("DELETING OBJECTS")
        
        persistentContainer.performBackgroundTask { privateManagedObjectContext in
            print("PERFORMING IN BGR 1")
            // Creates new batch delete request with a specific request
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

            // Asks to return the objectIDs deleted
            deleteRequest.resultType = .resultTypeObjectIDs

            do {
                
                print("PERFORMING IN BGR 2")
                // Executes batch
                let result = try privateManagedObjectContext.execute(deleteRequest) as? NSBatchDeleteResult

                // Retrieves the IDs deleted
                guard let objectIDs = result?.result as? [NSManagedObjectID] else {
                    print("CoreDataManager ERROR Removing: Objects retreived are not IDs")
                    return
                }
Thread.sleep(forTimeInterval:3)
                // Updates the main context
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.mainContext])
                print("PERFORMING IN BGR 3")
            } catch {
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
    
    public func saveContext(completion: @escaping () -> Void){
        guard setupWasCalled == true else{
            print("CoreDataManager ERROR: Setup method wasn't called, persistentStores may not be loaded.")
            return
        }
    }
    
}
