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
///
public final class CoreDataManager {

    public static let shared = CoreDataManager()
    
    private var setupWasCalled = false
    private var modelName : String!
    
    private var persistentContainerQueue : OperationQueue

    
    // ------------------------------------------------------------
    // PROPERTIES
    // ------------------------------------------------------------
    // MARK: - Properties
    lazy var persistentContainer: NSPersistentContainer! = {
        let persistentContainer = NSPersistentContainer(name: modelName )
        return persistentContainer
    }()
    
    /// An instance of `NSManagedObjectContext` that can be used for background operations.
    /// It's assigned automatically to a private background queue.
    public lazy var backgroundContext: NSManagedObjectContext = {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }()
    
    /// An instance of `NSManagedObjectContext` that can be used for standard operations.
    /// It's assigned automatically to the main queue.
    public lazy var mainContext: NSManagedObjectContext = {
        let context = persistentContainer.viewContext
        context.shouldDeleteInaccessibleFaults = true
        context.automaticallyMergesChangesFromParent = true
        return context
    }()

    
    // ------------------------------------------------------------
    // INIT-DEINIT
    // ------------------------------------------------------------
    // MARK: - Init-Deinit
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
    ///   - completion: A completion block that will be executed in the main thread whenever the setup finishes.
    ///   - error: If operation fails, completion block will be called with this value set, being nil if succeeded.
    public func setup(withModel name:String,
                      type: CoreDataManagerType ,
                      completion: @escaping (_ result:Result<Void,Error>) ->() ){

        setupWasCalled = true
        modelName = name
        
        guard Bundle.main.url(forResource: modelName, withExtension: "momd") != nil else{
            let error = CoreDataManagerError.modelNotFound(modelName)
            completion( .failure(error) )
            return
        }
    
        let description = NSPersistentStoreDescription()
        description.type = type.getString()
        description.configuration = "Default"
        persistentContainer.persistentStoreDescriptions = [description]
        
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
    
    
   
    // ------------------------------------------------------------
    // CREATE OPERATIONS
    // ------------------------------------------------------------
    // MARK: - Create Operations
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
    public func createObject(using block: @escaping (_ context:NSManagedObjectContext) -> () ) -> Result<Void,Error> {
        guard setupWasCalled == true else{
            return .failure( CoreDataManagerError.setupNotCalled )
        }
        
        var operationError : Error?
        
        // Blocking!
        mainContext.performAndWait {
            block(mainContext)
            if mainContext.hasChanges {
                do {
                    try mainContext.save()
                    
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
                                  completion: @escaping (_ result:Result<Void,Error>) ->() ){
        
        persistentContainerQueue.addOperation(){
            
            guard self.setupWasCalled == true else{
                DispatchQueue.main.async {
                    completion( .failure(CoreDataManagerError.setupNotCalled) )
                }
                return
            }
            
            self.backgroundContext.performAndWait{
                block(self.backgroundContext)
                
                if self.backgroundContext.hasChanges {
                     do{
                        try self.backgroundContext.save()
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
    public func fetchObject(using request: NSFetchRequest<NSManagedObject>) -> Result<[NSManagedObject],Error> {
        guard setupWasCalled == true else{
            return .failure( CoreDataManagerError.setupNotCalled )
        }
        
        var result : Result<[NSManagedObject],Error>!
        mainContext.performAndWait {
            do{
                let fetchResults = try mainContext.fetch(request)
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
    /// be executed automatically in the main queue, due to Core Data restrictions with multi-threading and NSManagedObject's
    /// context.
    ///
    /// - Parameters:
    ///   - request: The `NSFetchRequest` to use as an entity selector.
    ///   - completion: A completion block that will be called in the main thread, having a `Result` object representing
    ///   the operation's result.
    ///
    public func fetchObjectAsync(using request: NSFetchRequest<NSManagedObject>,
                                 completion: @escaping (_ result:Result<[NSManagedObject],Error>) ->() ){
        
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
                    var objectList = [NSManagedObject]()
                    for item in result {
                        let itemID = item.objectID
                        let queueSafeItem = self.mainContext.object(with: itemID)
                        objectList.append(queueSafeItem)
                    }
                    completion( .success(objectList) )
                }
            }
                
            // Fetch execution
            self.backgroundContext.performAndWait {
                do {
                    try self.backgroundContext.execute(backgroundAsyncRequest)
                    
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
    public func updateObject(using block: @escaping () -> () ) -> Result<Void,Error> {
        guard setupWasCalled == true else{
            return .failure( CoreDataManagerError.setupNotCalled )
        }
        
        var operationError : Error?
        
        // Blocking!
        mainContext.performAndWait {
            block()
            if mainContext.hasChanges {
                do {
                    try mainContext.save()
                    
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
    
    // No update async available due to threading issues
    
    // ------------------------------------------------------------
    // DELETE OPERATIONS
    // ------------------------------------------------------------
    // MARK: - Delete Operations
    /// Deletes all `NSManagedObject` entities selected by a `NSFetchRequest`.
    /// - Parameter request: The `NSFetchRequest` to use as an entity selector.
    public func deleteObject(using request: NSFetchRequest<NSManagedObject>) -> Result<Int,Error> {
        guard setupWasCalled == true else{
            return .failure( CoreDataManagerError.setupNotCalled )
        }
        
        var operationError : CoreDataManagerError?
        var deletedCount = 0
        mainContext.performAndWait {
            do {
                let objects = try mainContext.fetch(request)
                for object in objects {
                    mainContext.delete(object)
                    deletedCount += 1
                }
                
                if mainContext.hasChanges {
                    try mainContext.save()
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


    /// Deletes all `NSManagedObject` entities selected by a `NSFetchRequest`.
    /// - Parameter request: The `NSFetchRequest` to use as an entity selector.
    public func deleteObjectAsync(from request:NSFetchRequest<NSManagedObject>,
                                  completion: @escaping (_ result:Result<Int,Error>) ->() ){
        persistentContainerQueue.addOperation(){
            
            guard self.setupWasCalled == true else{
                DispatchQueue.main.async {
                    completion( .failure(CoreDataManagerError.setupNotCalled) )
                }
                return
            }
            
            self.backgroundContext.performAndWait {
                do {
                    var deletedCount = 0
                    let objects = try self.backgroundContext.fetch(request)
                    for object in objects {
                        self.backgroundContext.delete(object)
                        deletedCount += 1
                    }
                    
                    if self.backgroundContext.hasChanges {
                        try self.backgroundContext.save()
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
    
}
