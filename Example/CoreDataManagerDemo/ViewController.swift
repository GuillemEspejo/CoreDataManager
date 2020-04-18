//
//  ViewController.swift
//  CoreDataManagerDemo
//
//  Created by Guillem Espejo on 28/03/2020.
//  Copyright © 2020 Guillem Espejo. All rights reserved.
//

import UIKit
import CoreDataManager
import CoreData

class ViewController: UIViewController {

    @IBOutlet weak var labelResults: UILabel!
    @IBOutlet weak var btnFetch: UIButton!
    @IBOutlet weak var btnDelete: UIButton!
    @IBOutlet weak var btnCreate: UIButton!
    
    private var stackManager = CoreDataManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let completionBlock = {
            print("Core Data setup ended")
        }
        
        let errorBlock = { (error: Error?) in
            print("THERE WAS AN ERROR setting up core data: \(error)!!")
        }
        
        stackManager.setup(withModel: "Test", completion: completionBlock, error: errorBlock )

    }
    
    @IBAction func didTapCreate(_ sender: Any) {
        
        var taskNames = [String]()        
        for i in 0 ... 500000 {
            taskNames.append("Task \(i)")
        }
        
        let createBlock = { (context:NSManagedObjectContext) in
            for taskname in taskNames{
                let task = TodoTask(context: context)
                task.title = taskname
                task.done = true
            }
        }
        
        let errorBlock = { (error: Error?) in
            print("THERE WAS AN ERROR saving in core data: \(error)!!")
        }
        
        print("GOING TO SAVE!")
        stackManager.create(withBlock:createBlock, error:errorBlock)
        print("SAVED!")
    }
    
    @IBAction func didTapDelete(_ sender: Any) {
   
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = TodoTask.fetchRequest()
        /*fetchRequest.predicate = ...
        fetchRequest.sortDescriptors = ... */
        
        stackManager.deleteObjects(from:fetchRequest)
        
        /*
        DB.default.container.performBackgroundTask { context in
            ...
            context.delete(note)
            try! context.save()
        }
        */
    }
    
    @IBAction func didTapFetch(_ sender: Any) {
        print("TESTING TESTING TESTING")
/*
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = TodoTask.fetchRequest()
        /*fetchRequest.predicate = ...
        fetchRequest.sortDescriptors = ... */
        
        let tasks = stackManager.fetchObjects(from:fetchRequest) as! [TodoTask]
        
        for task in tasks {
            print(task.title!)
        }

        */
    }
    
}

