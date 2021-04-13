//
//  CoreDataManagerType.swift
//  CoreDataManager
//
//  Created by Guillem Espejo on 09/06/2020.
//  Copyright © 2020 GuillemEspejo. All rights reserved.
//

import Foundation
import CoreData

/// Stack type
///
/// An enum that represents the available Core Data stack types used by CoreDataManager.
/// The enum values are directly tied to Core Data string types.
///
/// Used when calling the setup method.
public enum CoreDataManagerType: Equatable {
    case standard
    case inmemory
    case binary
    
    public var typeString: String {
        switch self {
            case .standard: return NSSQLiteStoreType
            case .binary: return NSBinaryStoreType
            case .inmemory: return NSInMemoryStoreType
        }
    }

}
