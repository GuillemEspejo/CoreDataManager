//
//  CoreDataManagerError.swift
//  CoreDataManager
//
//  Created by Guillem Espejo on 18/04/2020.
//  Copyright © 2020 GuillemEspejo. All rights reserved.
//

import Foundation

/// CoreDataManager custom errors
///
/// This values are viewed from the outside of the framework as a normal Error with a
/// description set.
enum CoreDataManagerError : Error{
    case setupNotCalled
    case nilFetch
    case modelNotFound(String)
    case generic(Error)
}

extension CoreDataManagerError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
            case .setupNotCalled:
                return "CoreDataManager ERROR: Setup method wasn't called, persistentStores may not be loaded."
            
            case .nilFetch:
                return "CoreDataManager ERROR: Fetch returned nil."
            
            case .modelNotFound(let modelName):
                return "CoreDataManager ERROR: Model file '\(modelName)' not found when loading."
            
            case .generic(let error):
                return "CoreDataManager ERROR: \(error)"
        }
    }
}
