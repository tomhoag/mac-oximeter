//
//  Person+CoreDataProperties.swift
//  Oximeter
//
//  Created by Tom on 4/10/20.
//  Copyright © 2020 SquarePi Software. All rights reserved.
//
//

import Foundation
import CoreData


extension Person {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Person> {
        return NSFetchRequest<Person>(entityName: "Person")
    }

    @NSManaged public var id: String?
    @NSManaged public var firstName: String?
    @NSManaged public var lastName: String?
    @NSManaged public var report: NSSet?

}

// MARK: Generated accessors for report
extension Person {

    @objc(addReportObject:)
    @NSManaged public func addToReport(_ value: Report)

    @objc(removeReportObject:)
    @NSManaged public func removeFromReport(_ value: Report)

    @objc(addReport:)
    @NSManaged public func addToReport(_ values: NSSet)

    @objc(removeReport:)
    @NSManaged public func removeFromReport(_ values: NSSet)

}
