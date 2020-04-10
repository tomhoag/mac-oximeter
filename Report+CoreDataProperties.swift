//
//  Report+CoreDataProperties.swift
//  Oximeter
//
//  Created by Tom on 4/9/20.
//  Copyright © 2020 SquarePi Software. All rights reserved.
//
//

import Foundation
import CoreData


extension Report {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Report> {
        return NSFetchRequest<Report>(entityName: "Report")
    }

    @NSManaged public var data: String?
    @NSManaged public var header: String?
    @NSManaged public var id: String?
    @NSManaged public var number: Int16
    @NSManaged public var person: Person?

}
