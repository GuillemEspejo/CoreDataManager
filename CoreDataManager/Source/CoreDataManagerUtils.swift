//
//  CoreDataManagerUtils.swift
//  CoreDataManager
//
//  Created by Guillem Espejo on 18/04/2020.
//  Copyright © 2020 GuillemEspejo. All rights reserved.
//

import Foundation
import CoreData

// Custom type management
public enum CoreDataManagerType {
    case standard
    case inmemory
    case binary
    
    func getString() -> String{
        switch self {
            case .standard:
                return NSSQLiteStoreType
            case .inmemory:
                return NSInMemoryStoreType
            case .binary:
                return NSBinaryStoreType
        }
    }
}

// Custom error management
enum CoreDataManagerError : Error{
    case setupNotCalled
    case modelNotFound(String)
    case castFailed
    case notIds
    case generic(Error)
}

extension CoreDataManagerError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
            case .setupNotCalled:
                return "CoreDataManager ERROR: Setup method wasn't called, persistentStores may not be loaded."
            
            case .modelNotFound(let modelName):
                return "CoreDataManager ERROR: Model file '\(modelName)' not found when loading."
                
            case .castFailed:
                return "CoreDataManager ERROR: Can't cast to NSManagedObject when fetching asynchronously."
            
            case .notIds:
                return "CoreDataManager ERROR: Can't cast to NSManagedObjectID when deleting asynchronously."
            
            case .generic(let error):
                return "CoreDataManager ERROR: \(error)"
        }
    }
}
