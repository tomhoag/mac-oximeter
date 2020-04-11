//
//  Person+ComputedVars.swift
//  Oximeter
//
//  Created by Tom on 4/10/20.
//  Copyright © 2020 SquarePi Software. All rights reserved.
//

import Cocoa

extension Person {
    
    @objc dynamic var shortDescription:String {
        get {
            return ("\(self.id!) \(self.firstName ?? "") \(self.lastName ?? "")")
        }
    }
    
}
