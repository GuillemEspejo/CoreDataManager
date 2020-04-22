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
        let completionBlock = {  (error: Error?) in
            if let setupError = error {
                print("SETUP ERROR!: \(setupError)")
                return
            }
            
            print("Core Data setup ended")
        }

        stackManager.setup(withModel: "Test", completion: completionBlock )

    }
    
    @IBAction func didTapCreate(_ sender: Any) {
        
       
            
            print("THREAD CREATION 1: \(Thread.current)")
            let createBlock = { (context:NSManagedObjectContext) in
                print("THREAD CREATION BLOCK 1: \(Thread.current)")
                
                var taskNames = [String]()
                for i in 0 ... 500000 {
                    taskNames.append("Task \(i)")
                }
                
                
                for taskname in taskNames{
                    let task = TodoTask(context: context)
                    task.title = taskname
                    task.done = true
                    //print("CREATED TASK: \(task.title!)")
                }
                
                print("THREAD CREATION BLOCK 2: \(Thread.current)")
            }
        
            let completionBlock = { (error: Error?) in
                if let setupError = error {
                    print("CREATION ERROR!: \(setupError)")
                    return
                }
                
                print("Core Data creation ended")
            }

         
            print("THREAD CREATION 2: \(Thread.current)")
            let error = self.stackManager.createObject(using:createBlock)
            //self.stackManager.createObjectAsync(with:createBlock, completion: completionBlock)
            print("THREAD CREATION 3: \(Thread.current)")
        
        
        
        
    }
    
    @IBAction func didTapDelete(_ sender: Any) {
   /*
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = TodoTask.fetchRequest()
        /*fetchRequest.predicate = ...
        fetchRequest.sortDescriptors = ... */
        
        stackManager.deleteObjects(from:fetchRequest)
        */
        print("TAP TAP TAP")

    }
    
    @IBAction func didTapFetch(_ sender: Any) {
        
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = TodoTask.fetchRequest()
        /*fetchRequest.predicate = ...
        fetchRequest.sortDescriptors = ... */
        
        

            let completionBlock = { (result : Result<[NSManagedObject],Error>) in
                switch result {
                    case let .success(objects):
                       for task in objects {
                            let cast = task as? TodoTask
                            
                       }
                        print("SUCCESSSSSSSSSS!!")
                     print("LOLER 2: \(Thread.current)")
                    case let .failure(error):
                        print("THERE WAS AN ERROR FETCHING: \(error)")
                }
            }
            
            print("LOLER: \(Thread.current)")
            self.stackManager.fetchObjectsAsync(using: fetchRequest,
                                                completion: completionBlock)
        
        
/*
            let result = self.stackManager.fetchObjects(from: fetchRequest)
            
            switch result {
                case let .success(objects):
                
                        for task in objects {
                            let cast = task as? TodoTask
                        }
                    
                   
                    print("SUCCESSSSSSSSSS!!")
                case let .failure(error):
                    print("THERE WAS AN ERROR FETCHING: \(error)")
            }
  */
        

    }
    
}

