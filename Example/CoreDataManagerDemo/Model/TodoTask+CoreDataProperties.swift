//
//  TodoTask+CoreDataProperties.swift
//  CoreDataManagerDemo
//
//  Created by Guillem Espejo on 08/04/2020.
//  Copyright © 2020 Guillem Espejo. All rights reserved.
//
//

import Foundation
import CoreData


extension TodoTask {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TodoTask> {
        return NSFetchRequest<TodoTask>(entityName: "TodoTask")
    }

    @NSManaged public var title: String?
    @NSManaged public var done: Bool

}
