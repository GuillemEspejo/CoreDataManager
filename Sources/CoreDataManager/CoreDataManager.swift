//
//  CoreDataManager.swift
//  CoreDataManager
//
//  Created by Guillem Espejo on 22/03/2020.
//  Copyright © 2020 GuillemEspejo. All rights reserved.
//

import CoreData

/// Main Core Data stack class.
///
/// This class represents a fully functional Core Data stack based on a `NSPersistentContainer` setup. It gives access to some basic CRUD operations, with sync and async variants where possible.
///
/// It also gives access to a main and a background context, so you can use the methods provided
/// or the contexts depending on your needs.
///
public final class CoreDataManager {

    // ------------------------------------------------------------
    // PROPERTIES
    // ------------------------------------------------------------
    // MARK: - Properties
    //Public
    public static let shared = CoreDataManager()
    
    /// An instance of `NSManagedObjectContext` that can be used for standard operations.
    /// It's assigned automatically to the main queue.
    public lazy var mainContext: NSManagedObjectContext? = {
        guard setupWasCalled == true else{
            print( CoreDataManagerError.setupNotCalled.localizedDescription )
            return nil
        }
        let context = persistentContainer.viewContext
        context.shouldDeleteInaccessibleFaults = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }()
    
    
    /// An instance of `NSManagedObjectContext` that can be used for background operations.
    /// It's assigned automatically to a private background queue.
    public lazy var backgroundContext: NSManagedObjectContext? = {
        guard setupWasCalled == true else{
            print( CoreDataManagerError.setupNotCalled.localizedDescription )
            return nil
        }
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }()
    
    //Private
    private lazy var persistentContainer: NSPersistentContainer! = {
        let persistentContainer = NSPersistentContainer(name: modelName )
        return persistentContainer
    }()
    
    private var setupWasCalled = false
    private var modelName : String!
    private var stackType : CoreDataManagerType!
    private var persistentContainerQueue : OperationQueue


    // ------------------------------------------------------------
    // INIT
    // ------------------------------------------------------------
    // MARK: - Init
    private init(){
        persistentContainerQueue = OperationQueue()
        persistentContainerQueue.maxConcurrentOperationCount = 1
        persistentContainerQueue.name = "CoreDataManager Queue"
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
    ///   - type: Stack type, can be `standard`, `inmemory` or `binary`. Defaults to `standard`.
    ///   - completion: A completion block that will be executed in the main thread whenever the setup finishes.
    ///   - result: Result value of the operation, passed as parameter to the completion block. Can be `Void` or `Error`.
    public func setup(withModel name:String,
                      type: CoreDataManagerType = .standard ,
                      completion: @escaping (_ result:Result<Void,Error>) ->() ){

        setupWasCalled = true
        modelName = name
        stackType = type
        
        guard Bundle.main.url(forResource: modelName, withExtension: "momd") != nil else{
            let error = CoreDataManagerError.modelNotFound(modelName)
            completion( .failure(error) )
            return
        }
        
        let description = getStoreDescription()
        persistentContainer.persistentStoreDescriptions = [description]
        
        // Load in background...
        persistentContainerQueue.addOperation {
            self.persistentContainer.loadPersistentStores { description, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion( .failure(error) )
                    }else{
                        completion( .success(()) )
                    }
                }
            }
        }

    }
    
    private func getStoreDescription() -> NSPersistentStoreDescription{
        let description = NSPersistentStoreDescription()
        description.type = stackType.typeString
        description.configuration = "Default"
        
        let url = NSPersistentContainer.defaultDirectoryURL()
        let fileURL = url.appendingPathComponent( modelName + ".sqlite")
        
        description.url = fileURL
        
        return description
    }
   
    // ------------------------------------------------------------
    // CREATE OPERATIONS
    // ------------------------------------------------------------
    // MARK: - Create Operations
    ///
    /// Creates and inserts objects into Core Data stack.
    ///
    /// Use this method whenever you want to insert objects into Core Data. The method will take care of creating and saving
    /// the data to the persistent store.
    /// Due to this, so you should **only** use the context provided within the block as a parameter for the `NSManagedObject` constructor.
    /// Any other use can lead to unexpected behavior.
    ///
    /// This call will be internally attached to the **main queue** and will be **blocking**. Any use of an additional queue when creating
    /// the `NSManagedObject` will lead to crashes. This is standard Core Data behaviour as it's not thread safe.
    ///
    /// If you want a non blocking option, you must call `createObjectAsync`
    ///
    /// - Parameters:
    ///   - block: A creation block where you must create the `NSManagedObject` subclasses to be inserted into Core Data.
    ///   - context: An instance of an `NSManagedObjectContext` allowing you to create `NSManagedObject` subclasses.
    /// - Returns:
    ///   `Result` instance, being `Void` when succeeded or `Error` when failed.
    ///
    public func createObject(using block: @escaping (_ context:NSManagedObjectContext) -> () ) -> Result<Void,Error> {
        guard setupWasCalled == true else{
            return .failure( CoreDataManagerError.setupNotCalled )
        }
        
        var operationError : Error?
        let context = mainContext!
        
        // Blocking!
        context.performAndWait {
            block(context)
            if context.hasChanges {
                do {
                    try context.save()
                    
                }catch{
                    operationError = CoreDataManagerError.generic(error)
                }
            }
        }
        
        if let finalError = operationError {
            return .failure( finalError )
        }else{
            return .success(())
        }

    }
        
    ///
    /// Creates and inserts objects into Core Data stack asynchronously.
    ///
    /// Use this method whenever you want to insert objects into Core Data asynchronously. The method will take care of creating and saving the data to the persistent store.
    /// Due to this, so you should **only** use the context provided within the creation block as a parameter for
    /// the NSManagedObject constructor. Any other use can lead to unexpected behavior.
    ///
    /// This call will be internally attached to a **private queue** and will be asynchronous. The provided completion block will be executed always within the **main queue**.
    ///
    /// - Parameters:
    ///   - block: A creation block where you must create the `NSManagedObject` subclasses to be inserted into Core Data.
    ///   - context: An instance of an `NSManagedObjectContext` allowing you to create `NSManagedObject` subclasses.
    ///   - completion: A completion block that will be called on the **main queue** whenever the operation finishes with success or failure.
    ///   - result: `Result` instance, being `Void` when succeeded or `Error` when failed.
    ///
    public func createObjectAsync(using block: @escaping (_ context:NSManagedObjectContext) -> () ,
                                  completion: @escaping (_ result:Result<Void,Error>) ->() ){
        
        persistentContainerQueue.addOperation(){
            
            guard self.setupWasCalled == true else{
                DispatchQueue.main.async {
                    completion( .failure(CoreDataManagerError.setupNotCalled) )
                }
                return
            }
            
            let bgrContext = self.backgroundContext!
            bgrContext.performAndWait{
                block(bgrContext)
                
                if bgrContext.hasChanges {
                     do{
                        try bgrContext.save()
                     }catch{
                        DispatchQueue.main.async{
                            completion( .failure(CoreDataManagerError.generic(error)) )
                        }
                        return
                     }
                 }

                 DispatchQueue.main.async {
                    completion( .success(()) )
                 }
            }
        }
        
    }
    
    // ------------------------------------------------------------
    // READ OPERATIONS
    // ------------------------------------------------------------
    // MARK: - Read Operations
    ///
    /// Synchronously executes a fetch request.
    ///
    /// Use this method to fetch objects from Core Data using the **main queue**. This method is **blocking** so be
    /// careful when using it, as it may block UI updates if the query takes long enough.
    ///
    /// Due to the call being internally attached to the **main queue**, calling this method from any other thread
    /// will lead to crashes. This is standard Core Data behaviour as it's not thread safe.
    ///
    /// If you want a non blocking option, you must call `fetchObjectAsync`.
    ///
    /// - Parameters:
    ///   - request: The `NSFetchRequest` to use as an entity selector.
    /// - Returns:
    ///   `Result` instance, containing an array with the fetched `NSManagedObject` instances or an `Error` if the operation failed.
    ///
    public func fetchObject<T:NSManagedObject>(using request: NSFetchRequest<T>) -> Result<[T],Error> {
        guard setupWasCalled == true else{
            return .failure( CoreDataManagerError.setupNotCalled )
        }
        
        var result : Result<[T],Error>!
        let context = mainContext!
        
        // Blocking!
        context.performAndWait {
            do{
                let fetchResults = try context.fetch(request)
                result = .success(fetchResults)
                
            }catch{
                result = .failure( CoreDataManagerError.generic(error) )
            }
        }
        
        return result
    }

    
    ///
    /// Asynchronously executes a fetch request.
    ///
    /// Use this method to fetch objects from Core Data aynchronously. This method is **non blocking** ,
    /// so you must provide a completion block to get back the results.
    ///
    /// This call will be internally attached to a **private queue**. The provided completion block will
    /// be executed automatically in the **main queue**, allowing direct use of fetched objects in the main queue without violating Core Data's strict threading rules.
    ///
    /// - Parameters:
    ///   - request: The `NSFetchRequest` to use as an entity selector.
    ///   - completion: A completion block that will be called in the main thread, having a `Result` object representing the operation's result.
    ///   - result: `Result` instance, containing an array with the fetched `NSManagedObject` instances or an `Error` if the operation failed.
    ///
    public func fetchObjectAsync<T:NSManagedObject>(using request: NSFetchRequest<T>,
                                 completion: @escaping (_ result:Result<[T],Error>) ->() ){
        
        persistentContainerQueue.addOperation(){
            
            guard self.setupWasCalled == true else{
                DispatchQueue.main.async {
                    completion( .failure(CoreDataManagerError.setupNotCalled) )
                }
                return
            }
                   
           // Background async fetch request block
           let backgroundAsyncRequest = NSAsynchronousFetchRequest(fetchRequest: request) { asynchronousFetchResult in
                guard let result = asynchronousFetchResult.finalResult else {
                    DispatchQueue.main.async {
                        completion( .failure(CoreDataManagerError.nilFetch) )
                    }
                    return
                }
               
                // We refetch objects from its ObjectID in the main queue
                DispatchQueue.main.async {
                    var objectList = [T]()
                    let context = self.mainContext!
                    for item in result {
                        let queueSafeItem = context.object(with: item.objectID)
                        objectList.append(queueSafeItem as! T)
                    }
                    completion( .success(objectList) )
                }
            }
                
            // Fetch execution
            let bgrContext = self.backgroundContext!
            bgrContext.performAndWait {
                do {
                    try bgrContext.execute(backgroundAsyncRequest)
                    
                } catch {
                    DispatchQueue.main.async {
                        completion( .failure(CoreDataManagerError.generic(error)) )
                    }
                }
            }
        }
        
    }
    
    
    // ------------------------------------------------------------
    // UPDATE OPERATIONS
    // ------------------------------------------------------------
    // MARK: - Update Operations
    ///
    /// Synchronously updates objects in Core Data.
    ///
    /// Use this method whenever you want to update objects from Core Data. The method will take care of saving
    /// the data to the persistent store.
    ///
    /// This call will be internally attached to the **main queue** and will be **blocking**. Any use of an additional
    /// queue when updating the `NSManagedObject` will lead to crashes. This is standard Core Data behaviour as it's not thread safe.
    ///
    /// Due to the nature of the update operation and Core Data's threading rules, there is no easy way to achieve asynchronous updates within a single isolated method. Therefore there is no async option available.
    ///
    /// - Parameters:
    ///   - block: A block where you must modify the `NSManagedObject` subclasses to be updated in Core Data.
    /// - Returns:
    ///  `Result` instance, being `Void` when succeeded or `Error` when failed.
    ///
    public func updateObject(using block: @escaping () -> () ) -> Result<Void,Error> {
        guard setupWasCalled == true else{
            return .failure( CoreDataManagerError.setupNotCalled )
        }
        
        var operationError : Error?
        let context = self.mainContext!
        
        // Blocking!
        context.performAndWait {
            block()
            if context.hasChanges {
                do {
                    try context.save()
                    
                }catch{
                    operationError = CoreDataManagerError.generic(error)
                }
            }
        }
        
        if let finalError = operationError {
            return .failure( finalError )
        }else{
            return .success(())
        }
    }
    
    // No async update available due to threading issues
    
    
    // ------------------------------------------------------------
    // DELETE OPERATIONS
    // ------------------------------------------------------------
    // MARK: - Delete Operations
    ///
    /// Synchronously deletes objects in Core Data.
    ///
    /// Use this method to delete objects from Core Data using the **main queue**. This method is **blocking** so be careful when using it, as it may block UI updates if the process takes long enough.
    ///
    /// Due to the call being internally attached to the **main queue**, calling this method from any other thread will lead to crashes. This is standard Core Data behaviour as it's not thread safe.
    ///
    /// If you want a non blocking option, you must call `deleteObjectAsync`.
    ///
    /// - Parameters:
    ///   - request: The `NSFetchRequest` to use as an entity selector.
    /// - Returns:
    ///  `Result` instance, being `Int` or `Error`. If succeeded, Int value will be the count of deleted objects.
    ///
    public func deleteObject<T:NSManagedObject>(using request: NSFetchRequest<T>) -> Result<Int,Error> {
        guard setupWasCalled == true else{
            return .failure( CoreDataManagerError.setupNotCalled )
        }
        
        var operationError : CoreDataManagerError?
        var deletedCount = 0
        let context = self.mainContext!
        
        // Blocking!
        context.performAndWait {
            do {
                let objects = try context.fetch(request)
                for object in objects {
                    context.delete(object)
                    deletedCount += 1
                }
                
                if context.hasChanges {
                    try context.save()
                }
                
            } catch {
                operationError = CoreDataManagerError.generic(error)
            }
        }
        
        if let finalError = operationError {
            return .failure( finalError )
        }else{
            return .success(deletedCount)
        }
    }


    ///
    /// Asynchronously deletes objects in Core Data.
    ///
    /// Use this method to delete objects from Core Data aynchronously. This method is **non blocking**, so you can provide a completion block if needed.
    ///
    /// This call will be internally attached to a **private queue**. The provided completion block will be executed automatically in the **main queue**.
    ///
    /// - Parameters:
    ///   - request: The `NSFetchRequest` to use as an entity selector.
    ///   - completion: A completion block that will be called on the main thread, with a `Result` instance as parameter.
    ///   - result: `Result` instance, an Int indicating de count of deleted objects or an `Error` if the operation failed.
    ///
    public func deleteObjectAsync<T:NSManagedObject>(from request:NSFetchRequest<T>,
                                  completion: @escaping (_ result:Result<Int,Error>) ->() ){
        persistentContainerQueue.addOperation(){
            
            guard self.setupWasCalled == true else{
                DispatchQueue.main.async {
                    completion( .failure(CoreDataManagerError.setupNotCalled) )
                }
                return
            }
            
            let bgrContext = self.backgroundContext!
            bgrContext.performAndWait {
                do {
                    var deletedCount = 0
                    let objects = try bgrContext.fetch(request)
                    for object in objects {
                        bgrContext.delete(object)
                        deletedCount += 1
                    }
                    
                    if bgrContext.hasChanges {
                        try bgrContext.save()
                    }
                    
                    DispatchQueue.main.async {
                        completion( .success(deletedCount) )
                    }
                    
                } catch {
                    DispatchQueue.main.async {
                        completion( .failure(CoreDataManagerError.generic(error)) )
                    }
                }
            }
        }
    }
    
    // ------------------------------------------------------------
    // MISC OPERATIONS
    // ------------------------------------------------------------
    // MARK: - Misc Operations
    ///
    /// Removes all entities stored in Core Data.
    ///
    /// This method removes all entries stored within Core Data. This method operates
    /// directly against the persistent store layer, so it will **only** work when using
    /// an `.standard` stack type.
    ///
    /// If you want to clear all the entities when using any other stack type, you have
    /// to use the basic deletion methods, `deleteObject` or `deleteObjectAsync`
    ///
    /// - Returns:
    ///  `Result` instance, indicating success or failure.
    ///
    public func clearAllData() -> Result<Void,Error>{
        guard self.setupWasCalled == true else{
            return .failure( CoreDataManagerError.setupNotCalled )
        }
        
        guard self.stackType == .standard else {
            return .failure( CoreDataManagerError.wrongStoreType(stackType.typeString) )
        }
        
        // Get all entity names
        let names = persistentContainer.managedObjectModel.entities.map({ (entity) -> String in
            return entity.name!
        })
        
        // Delete them one by one
        for name in names {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: name)
            fetchRequest.returnsObjectsAsFaults = false
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDeleteRequest.resultType = .resultTypeObjectIDs
            
            do {
                let coordinator = persistentContainer.persistentStoreCoordinator
                let result = try coordinator.execute(batchDeleteRequest,
                                                     with: backgroundContext!) as! NSBatchDeleteResult
                // After deletion, changes are made directly in store, but not in memory.
                // So we must update the objects in memory by merging changes
                let changes: [AnyHashable: Any] = [
                    NSDeletedObjectsKey: result.result as! [NSManagedObjectID]
                ]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [mainContext!,backgroundContext!])
                
            } catch let error  {
                return .failure( CoreDataManagerError.generic(error) )
            }
            
        }
        
        return .success( () )
    }
    
    ///
    /// Returns a list of all NSEntityDescriptions stored within the model.
    ///
    /// - Returns:
    ///  An array of all the `NSEntityDescription` found within the object model.
    ///
    public func getEntityList() -> [NSEntityDescription]{
        return persistentContainer.managedObjectModel.entities
    }

}
