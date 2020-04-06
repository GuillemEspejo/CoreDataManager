//
//  ViewController.swift
//  CoreDataManagerDemo
//
//  Created by Guillem Espejo on 28/03/2020.
//  Copyright © 2020 Guillem Espejo. All rights reserved.
//

import UIKit
import CoreDataManager

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        CoreDataManager.shared.setup(withModel: "Test", completion: {
            print("HOLY CRAP, COREDATA SETUP ENDED!")
        })

    }


}

