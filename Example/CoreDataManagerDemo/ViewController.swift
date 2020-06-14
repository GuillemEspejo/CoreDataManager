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
    @IBOutlet weak var labelWorking: UILabel!

    private var stackManager = CoreDataManager.shared
    private static let objectLimit = 250
    private static var fetchedObjects = [TodoTask]()
    
    // Block used when inserting objects
    private let createBlock = { (context:NSManagedObjectContext) in
        for i in 1 ... ViewController.objectLimit {
            let task = TodoTask(context: context)
            task.title = "Task \(i)"
            task.done = false
        }
        Thread.sleep(forTimeInterval: 1.5) // Simulates longer operation
    }
    
    // Block used when updating objects
    private let updateBlock = {
        for task in fetchedObjects{
            task.done = true
        }
        Thread.sleep(forTimeInterval: 1.5) // Simulates longer operation
    }
    
    // ------------------------------------------------------------
    // LIFECYCLE
    // ------------------------------------------------------------
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Completion block when setup succeeds
        let completionBlock = { (result: Result<Void,Error>) in
            switch result {
                case .success():
                    print("Core Data setup ended")
                
                case .failure(let error):
                    print("Core Data setup error: \(error)")
            }
        }
      
        // Stack async setup
        self.stackManager.setup(withModel:"Test",
                                type: .inmemory ,
                                completion: completionBlock )
 
    }
    
    // ------------------------------------------------------------
    // CREATION
    // ------------------------------------------------------------
    // MARK: - Creation
    // Sync
    @IBAction func didTapCreate(_ sender: Any) {
        self.labelResults.text = "Awaiting results..."
        
        let result = self.stackManager.createObject(using:createBlock)
        switch result {
            case .success:
                self.labelResults.text = "Created \(ViewController.objectLimit) 'Todo' tasks"
            
            case .failure(let error):
                self.labelResults.text = error.localizedDescription
        }
        
        synchronicityLoop()
    }
    
    // Async
    @IBAction func didTapCreateAsync(_ sender: Any) {
        self.labelResults.text = "Awaiting results..."
        
        let completionBlock = { (result: Result<Void,Error>) in
            switch result {
                case .success:
                    self.labelResults.text = "Created \(ViewController.objectLimit) 'Todo' tasks"
                
                case .failure(let error):
                    self.labelResults.text = error.localizedDescription
            }
        }
        
        self.stackManager.createObjectAsync(using:createBlock, completion: completionBlock)
        synchronicityLoop()
    }
    
    // ------------------------------------------------------------
    // FETCHING
    // ------------------------------------------------------------
    // MARK: - Fetching
    // Sync
    @IBAction func didTapFetch(_ sender: Any) {
        self.labelResults.text = "Awaiting results..."
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TodoTask")
        let result = self.stackManager.fetchObject(using: fetchRequest)
    
        switch result {
            case let .success(objects):
                self.labelResults.text = "Fetched \(objects.count) 'Todo' tasks"
                let castedObjects = objects.map { (object) -> TodoTask in
                    return object as! TodoTask
                }
                ViewController.fetchedObjects.removeAll()
                ViewController.fetchedObjects.append(contentsOf: castedObjects)
            
            case .failure(let error):
                self.labelResults.text = error.localizedDescription
        }
        
        synchronicityLoop()
        
    }
    
    // Async
    @IBAction func didTapFetchAsync(_ sender: Any) {
        self.labelResults.text = "Awaiting results..."

        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TodoTask")
        
        let completionBlock = { (result : Result<[NSManagedObject],Error>) in
            switch result {
                case let .success(objects):
                    self.labelResults.text = "Fetched \(objects.count) 'Todo' tasks"
                    let castedObjects = objects.map { (object) -> TodoTask in
                        return object as! TodoTask
                    }
                    ViewController.fetchedObjects.removeAll()
                    ViewController.fetchedObjects.append(contentsOf: castedObjects)
                
                case .failure(let error):
                    self.labelResults.text = error.localizedDescription
            }
        }
            
        self.stackManager.fetchObjectAsync(using: fetchRequest, completion: completionBlock)
        synchronicityLoop()
    }
    
    // ------------------------------------------------------------
    // UPDATE
    // ------------------------------------------------------------
    // MARK: - Update
    // Sync
    @IBAction func didTapUpdate(_ sender: Any) {
        self.labelResults.text = "Awaiting results..."
        
        guard ViewController.fetchedObjects.count != 0 else{
            self.labelResults.text = "No objects to update, run Fetch first."
            return
        }
        
        let updateResult = stackManager.updateObject(using: updateBlock)
        
        switch updateResult {
            case .success():
                self.labelResults.text = "Updated \(ViewController.fetchedObjects.count) 'Todo' tasks"
            
            case .failure(let error):
                self.labelResults.text = error.localizedDescription
        }
        synchronicityLoop()
    }
    
    // No async update available
    
    
    // ------------------------------------------------------------
    // DELETE
    // ------------------------------------------------------------
    // MARK: - Delete
    // Sync
    @IBAction func didTapDelete(_ sender: Any) {
        self.labelResults.text = "Awaiting results..."

        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TodoTask")
        let result = stackManager.deleteObject(using: fetchRequest)
        
        switch result {
            case .success(let deletedCount):
                self.labelResults.text = "Deleted \(deletedCount) 'Todo' tasks"
            case .failure(let error):
                self.labelResults.text = error.localizedDescription
        }
        
        synchronicityLoop()
    }
    
    // Async
    @IBAction func didTapDeleteAsync(_ sender: Any) {
        self.labelResults.text = "Awaiting results..."

        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TodoTask")
        
        let completionBlock = { (result : Result<Int,Error>) in
            switch result {
                case let .success(objectCount):
                    self.labelResults.text = "Deleted \(objectCount) 'Todo' tasks"
                
                case .failure(let error):
                    self.labelResults.text = error.localizedDescription
            }
        }
            
        self.stackManager.deleteObjectAsync(from: fetchRequest, completion: completionBlock)
        synchronicityLoop()
    }


    // ------------------------------------------------------------
    // PRIVATE MISC
    // ------------------------------------------------------------
    // MARK: - Private misc
    // Simulates some working, updates the UI on the main thread
    private func synchronicityLoop(){
        DispatchQueue.global().async {
            for number in 0...3{
                DispatchQueue.main.async {
                    self.labelWorking.text = "Running loop... \(number)"
                }
                Thread.sleep(forTimeInterval: 1)
            }
            
            DispatchQueue.main.async {
                self.labelWorking.text = "Loop ended"
            }
        }
    }
    
}

