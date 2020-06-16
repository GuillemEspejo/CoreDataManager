<p align="center">
    <img src="docs/CoreData.png">
</p>

> Simple modern Core Data stack, for iOS, written in Swift .

[![Swift Version][swift-image]][swift-url]
[![Build Status][travis-image]][travis-url]
[![License][license-image]][license-url]
![Cocoapods Compatible](https://img.shields.io/cocoapods/v/StatefulCollections?style=plastic)
[![Platform](https://img.shields.io/cocoapods/p/StatefulCollections.svg?style=flat)](https://github.com/GuillemEspejo/CoreDataManager)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)

CoreDataManager is a small Swift framework that aims to simplify the setup and use of CoreData.

It works as a typical Core Data stack based on `NSPersistentContainer` setup, giving access to main and background contexts. It also gives access to all CRUD operations in a sync/async way, taking care of some of the common threading pitfalls that most users face.

## Features

- [x] Direct access to Core Data main and background contexts
- [x] Easy to use CRUD methods
- [x] Supports basic multithreading

## Requirements

- iOS 13.0+
- Xcode 11.3

## Installation

### CocoaPods

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate CoreDataManager into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'CoreDataManager'
```

## Setup

Before starting to use CoreDataManager, you have to set up the stack. This is done by calling the asynchronous `setup` method. You must pass the model name, the stack type and a completion block as parameters. The completion block will have a Result instance as parameter, allowing you to easily know if something failed.

You can access CoreDataManager stack by calling its singleton instance, then call `setup` on it.

```swift
import CoreDataManager
// Other imports ...

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let completionBlock = { (result: Result<Void,Error>) in
            switch result {
                case .success():
                    print("Core Data setup ended")
                  
                case .failure(let error):
                print("Core Data setup error: \(error)")
            }
        }
        
        let stack = CoreDataManager.shared
        stack.setup(withModel:"Test", type: .inmemory ,completion: completionBlock )

        // ...
    }
}
```

CoreDataManager offers three different type of basic stacks, based on `NSPersistentContainer` types. These are:  `.standard` , `.inmemory` and  `.binary`. You will usually use `.standard` type in most cases and `.inmemory` when writing Unit Tests.

## Basic usage

CoreDataManager offers two ways of operating. The first one is a traditional approach, in which the stack gives you access to two `NSManagedObjectContext` instances. One asociated with the main queue and another one associated to a background queue. It's up to you to use them properly.
The other way is by using the provided CRUD operation methods. They are less flexible than using the contexts directly, but they simplify the operations and take care of typical threading issues most people face when using Core Data.

## Usage via contexts

If you use CoreDataManager via direct context access, you have two properties:
- mainContext
- backgroundContext

This contexts are intrinsically associated to its queues, so any operation that uses them, must take this into account. 

As the name implies, `mainContext` is tied to the main queue, and must be used **always** within this queue. Objects fetched with this context will be tied to this queue as well.
If you try to access its objects from any other thread, it will crash. This is standard Core Data behaviour and can't be avoided.

On the other hand `backgroundContext` will allow you to use it and access its objects from a background queue. As with the main queue, the context and its objects are tied to the background queue, so any access from another thread will lead to crashes.

## Usage via CRUD operations

If you use CoreDataManager via CRUD operations, you will normally have two types of methods: Synchronous and asynchronous. There is only one exception, as there is no asynchronous Update due to the nature of the operation.

Depending on the operation, you will have to provide a block representing the operation you want to make or you will have to provide a `NSFetchRequest`. You will always receive via method return type or via completion block a `Result` instance indicating success or failure.

In the Example project you can find examples on how to use this methods.


### CRUD Examples
This examples are all called from the main thread. CoreDataManager will execute the operation in background automatically when executing Async version of the methods. If there are objects to be returned from an Async operation, they will be automatically delivered to the **main queue**, allowing direct UI modification if needed.

#### Synchronous Creation

```swift
¡
    // Creation block, TodoTask is an NSManagedObject subclass
    let createBlock = { (context:NSManagedObjectContext) in
        let task = TodoTask(context: context)
        task.title = "To do task"
        task.done = false
    }

    // stack is already inited...
    let result = stack.createObject(using:createBlock)

    switch result {
        case .success:
            print("Created objects successfuly")
        
        case .failure(let error):
            print("Error creating: \(error.localizedDescription)")
    }
¡
```
#### Asynchronous Creation

```swift
¡
    // Creation block, TodoTask is an NSManagedObject subclass
    let createBlock = { (context:NSManagedObjectContext) in
        let task = TodoTask(context: context)
        task.title = "To do task"
        task.done = false
    }

    // Completion block, has a Result parameter
    let completionBlock = { (result: Result<Void,Error>) in
        switch result {
            case .success:
                print("Created objects successfuly")
            
            case .failure(let error):
                print("Error creating: \(error.localizedDescription)")
        }
    }
    
    // stack is already inited...
    stack.createObjectAsync(using:createBlock, completion: completionBlock)
¡
```

#### Synchronous Fetch

```swift
¡
    
    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TodoTask")
    // stack is already inited...
    let result = stack.fetchObject(using: fetchRequest)
    
    switch result {
        case let .success(objects):
            let castedObjects = objects.map { (object) -> TodoTask in
                return object as! TodoTask
            }
            print(castedObjects)
        
        case .failure(let error):
            print("Error fetching: \(error.localizedDescription)")
    }
¡
```
#### Asynchronous Fetch

```swift
¡
    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TodoTask")
    
    let completionBlock = { (result : Result<[NSManagedObject],Error>) in
        switch result {
            case let .success(objects):
                let castedObjects = objects.map { (object) -> TodoTask in
                    return object as! TodoTask
                }
                print(castedObjects)
            
            case .failure(let error):
                print("Error fetching: \(error.localizedDescription)")
        }
    }
    
    // stack is already inited...
    stack.fetchObjectAsync(using: fetchRequest, completion: completionBlock)
¡
```

#### Synchronous Update

```swift
¡
    // TodoTask fetched anywhere...
    let task = fetchedTasks.first!

    let updateBlock = {
        task.done = true // Was false
    }

    // stack is already inited...
    let updateResult = stack.updateObject(using: updateBlock)
    
    switch updateResult {
        case .success:
            print("Updated objects successfuly")
        
        case .failure(let error):
            print("Error updating: \(error.localizedDescription)")
    }
¡
```

#### Synchronous Delete

```swift
¡
    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TodoTask")
    
    // stack is already inited...
    let result = stackManager.deleteObject(using: fetchRequest)
    
    switch result {
        case .success(let deletedCount):
            print("Deleted \(deletedCount) 'Todo' tasks")
            
        case .failure(let error):
            print("Error updating: \(error.localizedDescription)")
    }
¡
```
#### Asynchronous Delete

```swift
¡
    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TodoTask")
    
    let completionBlock = { (result : Result<Int,Error>) in
        switch result {
            case let .success(deletedCount):
                print("Deleted \(deletedCount) 'Todo' tasks")
            
            case .failure(let error):
                print("Error updating: \(error.localizedDescription)")
        }
    }
    
    // stack is already inited...
    stack.deleteObjectAsync(from: fetchRequest, completion: completionBlock)
¡
```

## Example

Download the example project to see how to use CoreDataManager CRUD operations.


## Contribute

If you want to contribute to **CoreDataManager**, check the ``LICENSE`` file for more info.

## Meta

Guillem Espejo –  g.espejogarcia@gmail.com

Distributed under the MIT license. See ``LICENSE`` for more information.

[https://github.com/GuillemEspejo/github-link](https://github.com/GuillemEspejo/)

[swift-image]:https://img.shields.io/badge/swift-5.0-orange.svg
[swift-url]: https://swift.org/
[travis-image]: https://img.shields.io/travis/dbader/node-datadog-metrics/master.svg?style=flat-square
[travis-url]: https://travis-ci.org/dbader/node-datadog-metrics
[license-image]: https://img.shields.io/badge/License-MIT-blue.svg
[license-url]: LICENSE
