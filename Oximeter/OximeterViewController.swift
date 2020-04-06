//
//  ViewController.swift
//  Oximeter
//
//  Created by Tom on 4/3/20.
//  Copyright © 2020 SquarePi Software. All rights reserved.
//

import Cocoa
import ORSSerial

class OximeterViewController: NSViewController, NSTableViewDelegate {

    @IBOutlet weak var reportTable: NSTableView!
    
    @objc dynamic let serialPortManager = ORSSerialPortManager.shared()
    @objc dynamic let boardController = OximeterDeviceController()
    
    @objc dynamic var selectionIndexes = IndexSet()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        reportTable.delegate = self
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    //  MARK: - reportTable Delegate
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let index = reportTable.selectedRow
        print("row clicked! \(index) \(notification)")
        boardController.getReportData(index: index)
        
    }
}

