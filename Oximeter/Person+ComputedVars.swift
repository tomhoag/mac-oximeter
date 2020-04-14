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
            let fname = (self.firstName ?? "")
            let sep1 = fname.count > 0 ? " " : ""
            var lname = ""
            if let last = self.lastName {
                if last.count > 0 {
                    lname = last.substring(from: 0, to: 1)
                }
            }
            let sep2 = lname.count > 0 ? " " : ""
            let idname = "(" + (self.id ?? "No ID") + ")"
            return fname + sep1 + lname + sep2 + idname
        }
    }
    
}
