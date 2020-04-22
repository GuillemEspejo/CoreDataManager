//
//  CoreDataManagerError.swift
//  CoreDataManager
//
//  Created by Guillem Espejo on 18/04/2020.
//  Copyright © 2020 GuillemEspejo. All rights reserved.
//

import Foundation

enum CoreDataManagerError : Error{
    case setupNotCalled
    case modelNotFound
    case castFailed
}

extension CoreDataManagerError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
            case .setupNotCalled:
                return "CoreDataManager ERROR: Setup method wasn't called, persistentStores may not be loaded."
            
            case .modelNotFound:
                return "CoreDataManager ERROR: Model file not found when loading."
                
            case .castFailed:
                return "CoreDataManager ERROR: Can't cast to NSManagedObject when fetching asynchronously"
        }
    }
}
