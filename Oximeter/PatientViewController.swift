//
//  PatientViewController.swift
//  Oximeter
//
//  Created by Tom on 4/10/20.
//  Copyright © 2020 SquarePi Software. All rights reserved.
//

import Cocoa

class PatientViewController: NSViewController, NSTableViewDelegate , NSTextFieldDelegate{
    
    @objc dynamic var managedContext: NSManagedObjectContext!
    @IBOutlet weak var patientTable: NSTableView!
    @IBOutlet weak var patientArrayController: NSArrayController!
    
    @IBAction func dismissPatientWindow(_ sender: NSButton) {
        guard let window = self.view.window, let parent = window.sheetParent else { return }
        self.managedContext.refreshAllObjects()        
        parent.endSheet(window, returnCode: .cancel)
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
                        UserDefaults.standard.bool(forKey: "NoPatientDeleteConfirmAlertSupression") ?
                            self.deletePatient(selectedPatient) :
                            self.confirmDeletePatientAlert { self.deletePatient(selectedPatient) }
                    }
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        patientTable.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(editingDidEnd(_:)), name: NSControl.textDidEndEditingNotification, object: nil)
    }
    
    @objc func editingDidEnd(_ obj: Notification) {
        guard let _ = (obj.object as? NSTextField)?.stringValue else {
            print("oops")
            return
        }
        let index = patientTable.selectedRow
        if index > -1 {
            let patients = self.patientArrayController.selectedObjects
            guard patients!.count > 0 else {
                return
            }
            try?managedContext.save()
        }
    }
    // MARK: - TableViewDelegate
    
    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        if edge == .trailing {
            let deleteAction = NSTableViewRowAction(style: .destructive, title: "Delete") { (action, index) in
                print("Now Deleting . . .")
                let patients = self.patientArrayController.selectedObjects
                guard patients!.count > 0 else {
                    return
                }
                
                if let selectedPatient = patients![0] as? Person {
                    UserDefaults.standard.bool(forKey: "NoPatientDeleteConfirmAlertSupression") ?
                        self.deletePatient(selectedPatient) :
                        self.confirmDeletePatientAlert { self.deletePatient(selectedPatient) }
                }
            }
            return [deleteAction]
        }
        return [NSTableViewRowAction]()
    }
    
    // MARK: - Alerts
    
    func confirmDeletePatientAlert(  _ onDelete: @escaping ()->Void ) {
        let alert = NSAlert()
        
        alert.messageText = "Delete Patient?"
        alert.informativeText = "Deleting a patient cannot be undone."
        alert.showsSuppressionButton = true
        
        alert.suppressionButton?.title = "I got it, don't show me this message again."
        alert.suppressionButton?.target = self
        
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete")

        alert.suppressionButton?.action = #selector(handleNoPatientDeleteAlertSuppressionButtonClick)
        
        alert.beginSheetModal(for: self.view.window!) { (response) in
            if response == .alertSecondButtonReturn { // Delete
                onDelete()
            }
        }
    }
    
    @objc func handleNoPatientDeleteAlertSuppressionButtonClick(_ suppressionButton: NSButton) {
        UserDefaults.standard.set(true, forKey: "NoPatientDeleteConfirmAlertSupression")
    }
    
    // MARK: - CRUD
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
