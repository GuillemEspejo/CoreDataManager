//
//  CoreDataManager.swift
//  CoreDataManager
//
//  Created by Guillem Espejo on 22/03/2020.
//  Copyright © 2020 GuillemEspejo. All rights reserved.
//

import CoreData

/// A class representing a full Core Data Stack.
///
/// Todo
///
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
    
    /// An instance of `NSManagedObjectContext` that can be used for background operations.
    /// It's assigned automatically to a private background queue.
    public lazy var backgroundContext: NSManagedObjectContext = {
        let context = self.persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }()
    
    /// An instance of `NSManagedObjectContext` that can be used for standard operations.
    /// It's assigned automatically to the main queue.
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
    ///
    /// Initializes **CoreDataManager** stack.
    ///
    /// This method must be called before doing any other operation related to Core Data when using CoreDataManager.
    /// As the initialization of Core Data is inherently asynchronous, it accepts a completion block.
    /// - Parameters:
    ///   - name: Core Data model filename.
    ///   - completion: A completion block that will be executed in the main thread whenever the setup finishes.
    ///   - error: If operation fails, completion block will be called with this value set, being nil if succeeded.
    public func setup(withModel name:String, completion: @escaping (_ error: Error?) -> () ){
        self.setupWasCalled = true
        self.modelName = name
        
        guard Bundle.main.url(forResource: self.modelName, withExtension: "momd") != nil else{
            completion(CoreDataManagerError.modelNotFound)
            return
        }

        self.persistentContainer.loadPersistentStores { description, error in
            completion(error)            
        }
    }
    
    // ------------------------------------------------------------
    // CRUD OPERATIONS
    // ------------------------------------------------------------
    // MARK: - CRUD Operations
   
    // ------------------------------------------------------------
    // CREATE
    ///
    /// Creates and inserts objects in Core Data.
    ///
    /// Use this method whenever you want to insert objects into Core Data. The method will take care of creating and saving
    /// the data to the persistent store.
    /// Due to this, so you should **only** use the context provided within the block as a parameter for the NSManagedObject constructor.
    /// Any other use can lead to unexpected behavior.
    ///
    /// This call will be internally attached to the main queue and will be **blocking**. Any use of an additional queue when creating
    /// the NSManagedObject will lead to crashes. This is standard Core Data behaviour as it's not thread safe.
    ///
    /// If you want a non blocking option, you must call `createObjectAsync`
    ///
    /// - Parameters:
    ///   - block: A creation block where you must create the NSManagedObject subclasses to be inserted into Core Data.
    ///   - context: An instance of an NSManagedObjectContext allowing you to create NSManagedObject subclasses.
    /// - Returns:
    ///   An optional `Error` that will be nil if operation succeeds.
    ///
    public func createObject(using block: @escaping (_ context:NSManagedObjectContext) -> () ) -> Error?{
        guard setupWasCalled == true else{
            return CoreDataManagerError.setupNotCalled
        }
        
        var operationError : Error?
        
        // Blocking!
        mainContext.performAndWait {
            block(mainContext)
            if mainContext.hasChanges {
                do {
                    try mainContext.save()
                } catch {
                    operationError = error
                }
            }
        }
        
        return operationError

    }
        
    ///
    /// Creates and inserts objects in Core Data asynchronously.
    ///
    /// Use this method whenever you want to insert objects into Core Data asynchronously. The method will take care
    /// of creating and saving the data to the persistent store.
    /// Due to this, so you should **only** use the context provided within the creation block as a parameter for
    /// the NSManagedObject constructor. Any other use can lead to unexpected behavior.
    ///
    /// This call will be internally attached to a **private queue** and will be **asynchronous**. The provided
    /// completion block will be executed within this same queue, so if you perform UI operations, remember to excute
    /// them in the main thread.
    ///
    /// - Parameters:
    ///   - block: A creation block where you must create the NSManagedObject subclasses to be inserted into Core Data.
    ///   - context: An instance of an NSManagedObjectContext allowing you to create NSManagedObject subclasses.
    ///   - completion: An instance of an NSManagedObjectContext allowing you to create NSManagedObject subclasses.
    ///   - error: If operation fails, completion block will be called with this value set, being nil if succeeded.
    ///
    public func createObjectAsync(using block: @escaping (_ context:NSManagedObjectContext) -> () ,
                                  completion: @escaping (_ error: Error?) -> () ){
        guard setupWasCalled == true else{
            completion(CoreDataManagerError.setupNotCalled)
            return
        }
        
        // Creates a task with a new background context created on the fly
        persistentContainer.performBackgroundTask { context in
            
            block(context)
            
            if context.hasChanges {
                do {
                    try context.save()
                    
                } catch {
                    completion(error)
                    return
                }
            }
            
            completion(nil)
        }
        
    }
    
    // ------------------------------------------------------------
    // READ
    ///
    /// Synchronously executes a fetch request.
    ///
    /// Use this method to fetch objects from Core Data using the main queue. This method is **blocking** so be
    /// careful when using it, as it may block UI updates if it does not finish fast enough.
    ///
    /// Due to the call being internally attached to the main queue, calling this method from any other thread
    /// will lead to crashes. This is standard Core Data behaviour as it's not thread safe.
    ///
    /// If you want a non blocking option, you must call `fetchObjectsAsync`.
    ///
    /// - Parameters:
    ///   - request: The `NSFetchRequest` to use as an entity selector.
    /// - Returns:
    ///   `Result` object, containing an array with the fetched `NSManagedObject` instances or an `Error` if the operation failed.
    ///
    public func fetchObjects(using request: NSFetchRequest<NSFetchRequestResult>) -> Result<[NSManagedObject],Error> {
        do{
            guard let result = try mainContext.fetch(request) as? [NSManagedObject] else {
                return .failure(CoreDataManagerError.castFailed)
            }
            return .success(result)
            
        }catch{
            return .failure(error)
        }
    }

    
    ///
    /// Asynchronously executes a fetch request.
    ///
    /// Use this method to fetch objects from Core Data aynchronously. This method is **non blocking** ,
    /// so you must provide a completion block to get back the results.
    ///
    /// This call will be internally attached to a **private queue**. The provided completion block will
    /// be executed automatically in the main queue, due to Core Data restrictions with multi-threading and NSManagedObject's
    /// context.
    ///
    /// - Parameters:
    ///   - request: The `NSFetchRequest` to use as an entity selector.
    ///   - completion: A completion block that will be called in the main thread, having a `Result` object representing
    ///   the operation's result.
    ///
    public func fetchObjectsAsync(using request: NSFetchRequest<NSFetchRequestResult>,
                                  completion: @escaping (_ result:Result<[NSManagedObject],Error>) ->() ){
        guard setupWasCalled == true else{
            completion( .failure(CoreDataManagerError.setupNotCalled) )
            return
        }
        
        // Creates `asynchronousFetchRequest` with the fetch request and the completion closure
        let asynchronousFetchRequest = NSAsynchronousFetchRequest(fetchRequest: request) { asynchronousFetchResult in
 
            guard let result = asynchronousFetchResult.finalResult as? [NSManagedObject] else {
                return completion( .failure(CoreDataManagerError.castFailed) )
            }
            
            // We refetch objects from its ObjectID in the main queue
            DispatchQueue.main.async {
                var objectList = [NSManagedObject]()
                for item in result {
                    let itemID = item.objectID
                    let queueSafeItem = self.mainContext.object(with: itemID)
                    objectList.append(queueSafeItem)
                }
                completion(.success(objectList))
            }
        }
        
        persistentContainer.performBackgroundTask { (context) in
            do {
               try context.execute(asynchronousFetchRequest)
           } catch {
               completion(.failure(error))
           }
        }

    }
    
    
    // ------------------------------------------------------------
    // UPDATE
    ///
    /// Updates objects in Core Data.
    ///
    /// Use this method whenever you want to update objects from Core Data. The method will take care of saving
    /// the data to the persistent store.
    ///
    /// This call will be internally attached to the main queue and will be **blocking**. Any use of an additional
    /// queue when updating the NSManagedObject will lead to crashes. This is standard Core Data behaviour as it's
    /// not thread safe.
    ///
    /// If you want a non blocking option, you must call `updateObjectAsync`
    ///
    /// - Parameters:
    ///   - block: A block where you must modify the NSManagedObject subclasses to be updated in Core Data.
    /// - Returns:
    ///   An optional `Error` that will be nil if operation succeeds.
    ///
    public func updateObject(using block: @escaping () -> () ) -> Error?{
        guard setupWasCalled == true else{
            return CoreDataManagerError.setupNotCalled
        }
        
        var operationError : Error?
        
        // Blocking!
        mainContext.performAndWait {
            block()
            if mainContext.hasChanges {
                do {
                    try mainContext.save()
                } catch {
                    operationError = error
                }
            }
        }
        
        return operationError
    }
    
    
    public func updateObjectAsync(){
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
    public func deleteObjects(using request: NSFetchRequest<NSFetchRequestResult>) -> Error? {
        return nil
    }
    
    /// Deletes all `NSManagedObject` entities selected by a `NSFetchRequest`.
    /// - Parameter request: The `NSFetchRequest` to use as an entity selector.
    public func deleteObjectsAsync(from request:NSFetchRequest<NSFetchRequestResult>) {
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
        for object in mainContext.registeredObjects {
            mainContext.refresh(object, mergeChanges: false)
        }
        
        mainContext.reset()
    }

    
}
