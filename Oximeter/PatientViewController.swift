//
//  PatientViewController.swift
//  Oximeter
//
//  Created by Tom on 4/10/20.
//  Copyright © 2020 SquarePi Software. All rights reserved.
//

import Cocoa

class PatientViewController: NSViewController, NSTableViewDelegate {

    @objc dynamic var managedContext: NSManagedObjectContext!
    @IBOutlet weak var patientTable: NSTableView!
    @IBOutlet weak var patientArrayController: NSArrayController!
    
    @IBAction func dismissPatientWindow(_ sender: NSButton) {
        NSApplication.shared.stopModal()
    }
    
    @IBAction func rowManagement(_ sender: Any) {
        
        if let control = sender as? NSSegmentedControl {
            if 0 == control.selectedSegment {
                let id = String(Int(NSDate().timeIntervalSince1970 * 100))
                createPatient(id:String(id))
                
            } else if 1 == control.selectedSegment {
                // remove
                if patientTable.selectedRow > -1 {
                    self.patientArrayController.setSelectionIndex(patientTable.selectedRow)
                    let patients = self.patientArrayController.selectedObjects
                    guard patients!.count > 0 else {
                        return
                    }
                    if let selectedPatient = patients![0] as? Person {
                        self.deletePatient(selectedPatient)
                    }
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder:coder)
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else {
            return
        }
        managedContext = appDelegate.persistentContainer.viewContext
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        patientTable.delegate = self
        // Do view setup here.
    }
    
    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
           if edge == .trailing {
               let deleteAction = NSTableViewRowAction(style: .destructive, title: "Delete") { (action, index) in
                   print("Now Deleting . . .")
                   let patients = self.patientArrayController.selectedObjects
                   guard patients!.count > 0 else {
                       return
                   }
                   
                   if let selectedPatient = patients![0] as? Person {
                       self.deletePatient(selectedPatient)
                   }
               }
               return [deleteAction]
           }
           return [NSTableViewRowAction]()
       }
    
    fileprivate func createPatient(id:String = UUID().uuidString, firstName:String="", lastName:String="") {
        let entity = NSEntityDescription.entity(forEntityName: "Person", in: managedContext)!
        let person = NSManagedObject(entity: entity, insertInto: managedContext) as? Person
        person!.id = id
        person!.firstName = firstName
        person!.lastName = lastName
        try! managedContext.save()
    }
    
     fileprivate func deletePatient(_ patient:Person) {
           managedContext.delete(patient)
           try! managedContext.save()
       }
}
