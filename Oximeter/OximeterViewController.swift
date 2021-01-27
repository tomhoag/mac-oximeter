//
//  ViewController.swift
//  Oximeter
//
//  Created by Tom on 4/3/20.
//  Copyright © 2020 SquarePi Software. All rights reserved.
//

import Cocoa
import ORSSerial
import Charts
import CoreData
import AppKit


class OximeterViewController: NSViewController, NSTableViewDelegate {
    
    // MARK: - Bound Items
    
    @objc dynamic var chartTitle = ""
    
    @objc dynamic var managedContext: NSManagedObjectContext!
    
    // MARK: - Outlets & Actions
    @IBOutlet var personArrayController: NSArrayController!
    @IBOutlet var reportArrayController: NSArrayController!
    @IBOutlet weak var reportTable: NSTableView!
    @IBOutlet weak var chartView: LineChartView!
            
    @IBAction func showDownloadManager(_ sender:NSButton) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let downloadViewController = storyboard.instantiateController(withIdentifier: "Download VC") as! DownloadViewController
        downloadViewController.managedContext = managedContext
        self.presentAsSheet(downloadViewController)
    }

    @IBAction func showPatientWindow(_ sender: Any) {
        
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let patientWindowController = storyboard.instantiateController(withIdentifier: "Patient Window") as! NSWindowController
        
        let patientWindow = patientWindowController.window
        
        let pvc = patientWindow?.contentViewController as! PatientViewController
        pvc.managedContext = managedContext
        
        self.view.window?.beginSheet(patientWindow!, completionHandler: { (response) in
            patientWindow!.close()
        })

    }
    
    @IBAction func rowManagement(_ sender: Any) {
        
        if let control = sender as? NSSegmentedControl {
            if 0 == control.selectedSegment  {
                // remove
                if reportTable.selectedRow > -1 {
                    self.reportArrayController.setSelectionIndex(reportTable.selectedRow)
                    let reports = self.reportArrayController.selectedObjects
                    guard reports!.count > 0 else {
                        return
                    }
                    if let selected = reports![0] as? Report {
                        UserDefaults.standard.bool(forKey: "NoRecordDeleteAlertSuppression") ?
                            self.deleteReport(selected) :
                            self.confirmDeleteRecordAlert({ self.deleteReport(selected) })
                    }
                }
            }
        }
    }
    
    @IBAction func popupSelectin(_ sender: Any) {

        if let pu = sender as? OximeterPopUpButton {
            let reports = reportArrayController.selectedObjects
            guard reports!.count > 0 else {
                return
            }
            
            if personArrayController.setSelectionIndex(pu.indexOfSelectedItem) {
                if let selectedReport = reports![0] as? Report {
                    saveReport(selectedReport)
                    hidePersonPopUps()
                }
            }
        }
    }
    
    // MARK: - ViewController
    
    required init?(coder: NSCoder) {
        super.init(coder:coder)
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else {
            return
        }
        managedContext = appDelegate.persistentContainer.viewContext
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        reportArrayController.addObserver(self, forKeyPath: "selectedObjects", options: .new, context: nil)
        
        chartView.noDataText = "Select a report above"
        chartView.backgroundColor = NSUIColor.white
        chartView.legend.font = NSUIFont(name: "HelveticaNeue-Light", size: CGFloat(14.0))!
        chartView.xAxis.valueFormatter = XAxisDateFormatter()
        
        reportTable.delegate = self
        reportTable.doubleAction = #selector(tableDoubleClick)
        
        reportTable.tableColumns.forEach { (column) in // why can't this be done in the storyboard??
            let exAttr = NSMutableAttributedString(attributedString: column.headerCell.attributedStringValue)
            exAttr.replaceFont(with: NSFont.systemFont(ofSize: 16))
            
            let oxc = OximeterTableHeaderCell()
            oxc.attributedStringValue = exAttr
            column.headerCell = oxc
        }
    }
    
    override func viewDidAppear() {
        
//        let daysToAdd = 17
//        var newDate = Calendar.current.date(byAdding: .day, value: daysToAdd, to: Date())
//        newDate = Calendar.current.date(byAdding: .day, value: daysToAdd, to: newDate!)
//        print(newDate?.timeIntervalSince1970)
        
        if Date().timeIntervalSince1970 > 1589821630 {
            let alert = NSAlert.init()
            alert.messageText = "DEMO EXPIRED"
            alert.informativeText = "The demonstration period for this application has expired."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Quit")
            
            alert.beginSheetModal(for: self.view.window!) { (response) in
                NSApplication.shared.terminate(self)
            }
        } else {
            
            let alert = NSAlert.init()
            alert.messageText = "DEMO ONLY"
            alert.informativeText = "This is a demo application.\n\nNumbers, results and images displayed are for demonstration purposes only and should not be relied on for any other purposes.\n\nPlease click 'I Agree' to accept these terms and continue."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "I Agree")
            alert.beginSheetModal(for: self.view.window!) { (response) in
                if response == .alertFirstButtonReturn { // Cancel
                    NSApplication.shared.terminate(self)
                }
            }
        }
    }
    
    // MARK: - NSTableView Delegate & Callbacks
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let result = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self)
        
        if let r = result as? OximeterPersonCellView {
            r.personPopup.isHidden = true
            return r
        }
        return result
    }
    
    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        if edge == .trailing {
            let deleteAction = NSTableViewRowAction(style: .destructive, title: "Delete") { (action, index) in
                print("Now Deleting . . .")
                let reports = self.reportArrayController.selectedObjects
                guard reports!.count > 0 else {
                    return
                }
                
                if let selectedReport = reports![0] as? Report {
                    UserDefaults.standard.bool(forKey: "NoRecordDeleteAlertSuppression") ?
                        self.deleteReport(selectedReport) :
                        self.confirmDeleteRecordAlert({ self.deleteReport(selectedReport) })
                }
            }
            return [deleteAction]
        }
        return [NSTableViewRowAction]()
    }
    
    @objc func tableDoubleClick(_ sender:Any) {
        
        hidePersonPopUps()
        
        if reportTable.clickedColumn == 4 && reportTable.clickedRow >= 0 {
            let clickedCellView = reportTable.view(atColumn:reportTable.clickedColumn, row:reportTable.clickedRow, makeIfNecessary:false) as! OximeterPersonCellView
            clickedCellView.textField!.isHidden = true
            clickedCellView.personPopup!.isHidden = false
        }
    }
    
    func hidePersonPopUps() {
        for i in 0..<reportTable.numberOfRows {
            if let view = reportTable.view(atColumn:4, row:i, makeIfNecessary:false) as? OximeterPersonCellView {
                view.textField!.isHidden = false
                view.personPopup.isHidden = true
            }
        }
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    // MARK: - Charts
    
    func chartUpdate(_ report:Report) {
        
        guard report.data != "" else {
            chartView.clear()
            let alert = NSAlert.init()
            alert.messageText = "Report has no data"
            alert.informativeText = "The selected report has no data."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.beginSheetModal(for: self.view.window!) { (response) in }
            return
        }
        
        let interval = report.timingInterval
        let startDateInterval = report.start.timeIntervalSince1970
        
        var lineChartEntry = [ChartDataEntry]()
        for i in 0..<report.pulse.count {
            let value = ChartDataEntry(x:startDateInterval + Double(i*interval), y: Double(report.pulse[i]))
            lineChartEntry.append(value)
        }
        
        let pulseLine = LineChartDataSet(entries: lineChartEntry, label: "PR(bpm)")
        pulseLine.colors = [NSUIColor.green]
        pulseLine.drawCirclesEnabled = false
        pulseLine.drawValuesEnabled = false
        
        let data = LineChartData()
        data.addDataSet(pulseLine)
        
        lineChartEntry = [ChartDataEntry]()
        for i in 0..<report.sp02.count {
            let value = ChartDataEntry(x:startDateInterval + Double(i*interval), y: Double(report.sp02[i]))
            lineChartEntry.append(value)
        }
        let sp02Line = LineChartDataSet(entries: lineChartEntry, label: "Sp02(%)")
        sp02Line.colors = [NSUIColor.red]
        sp02Line.drawCirclesEnabled = false
        sp02Line.drawValuesEnabled = false
        
        data.addDataSet(sp02Line)
        
        chartView.data = data
        
        chartView.animate(xAxisDuration: 1.0, yAxisDuration: 0.0)
        chartTitle = "\(report.startDate) - \(report.endDate) Interval:\(report.timingInterval) Mode:\(report.mode)"
    }
    
    /**
     Select Table View > Bindings inspector > Selection Indexes > Bind to the Array Controller
     Set Controller Key to selectionIndexes
     To observe the selected objects, set up observation in viewDidLoad
     */
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else { return }

        switch keyPath {
            
        case "selectedObjects":
            
            if let arrayController = object as? NSArrayController {
                if arrayController.entityName == "Report" {
                    
                    hidePersonPopUps()
                    let reports = arrayController.selectedObjects
                    
                    guard reports!.count > 0 else {
                        return
                    }
                    
                    if let selected = reports![0] as? Report {
                        if let _ = selected.data {
                            chartUpdate(selected)
                        } else {
                            chartView.clear()
                        }
                    }
                }
            }
            
        default: break
        }
    }
    
    
    
    // MARK: - Core Data
    
    func saveMockReports() {
        var header = "200328205541012200B4"
        var data = "5e00385e00375e00375e00375e00375e00375e00375e00385e00385e00395e00395e00395f003a5f003a5f003a5f00395e00385e00375f00375f00365f00365f00375f00375f00385f00385f00385f00395e00395f00395f00395f00395f00385f00375f00375f00375f00375f00385f00395f00395f00385f00385f00395f00395f00385f00385f00375f00375f00375f00375f00375f00385f00395f00395f00395f00395f00395f00385f00385f00385f00385f00385f00385f00385f00375f00375f00375f00375f00375f00385f00395e00395e00395e00395d00385d00385d00385e00385e00395e00395f00395f003a5f003a5f003a"
        saveMockReport(header:header, data:data, person:true)
        
        data = data + "5e00"
        header = "20032720280201420078"
        saveMockReport(header:header, data:data, person:false)
    }
    
    func saveMockReport(header:String, data:String?, person:Bool) {
        let entity = NSEntityDescription.entity(forEntityName: "Report", in: managedContext)!
        let report = NSManagedObject(entity: entity, insertInto: managedContext) as? Report
        report!.setValue(header, forKeyPath: "header")
        if let data = data {
            report!.setValue(data, forKeyPath: "data")
        }
        
        if person {
            report!.person = mockPerson
        }
        
        managedContext.mergePolicy =  NSMergeByPropertyObjectTrumpMergePolicy
        do {
            try managedContext.save()
            
        } catch let error as NSError {
            print(">>>> Could not save. \(error), \(error.userInfo) \(error.localizedDescription)")
        }
    }
    
    func saveReport(_ report:Report) {
        
        managedContext.mergePolicy =  NSMergeByPropertyObjectTrumpMergePolicy
        do {
            try managedContext.save()
            
        } catch let error as NSError {
            print(">>>> Could not save. \(error), \(error.userInfo) \(error.localizedDescription)")
        }
    }
    
    func deleteReport(_ report:Report) {
        managedContext.delete(report)
        try! managedContext.save()
    }
    
    var mockPerson:Person?
    
    func savePersonNamed(_ name:String) {
        
        managedContext.mergePolicy =  NSMergeByPropertyObjectTrumpMergePolicy
        
        let entity = NSEntityDescription.entity(forEntityName: "Person", in: managedContext)!
        let person = NSManagedObject(entity: entity, insertInto: managedContext) as? Person
        person!.setValue(name, forKeyPath: "firstName")
        
        mockPerson = person
        do {
            try managedContext.save()
            
        } catch let error as NSError {
            print(">>>> Could not save. \(error), \(error.userInfo) \(error.localizedDescription)")
        }
    }
    
    // MARK: - Alerts
    
    func confirmDeleteRecordAlert(  _ onDelete: @escaping ()->Void ) {
        let alert = NSAlert()
        
        alert.messageText = "Delete Record?"
        alert.informativeText = "Deleting a record cannot be undone."
        alert.showsSuppressionButton = true
        
        alert.suppressionButton?.title = "I got it, don't show me this message again."
        alert.suppressionButton?.target = self
        
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete")
        
        alert.suppressionButton?.action = #selector(handleNoRecordDeleteAlertSuppressionButtonClick(_:))
        
        alert.beginSheetModal(for: self.view.window!) { (response) in
            if response == .alertSecondButtonReturn { // Delete
                onDelete()
            }
        }
    }
    
    @objc func handleNoRecordDeleteAlertSuppressionButtonClick(_ suppressionButton: NSButton) {
        UserDefaults.standard.set(true, forKey: "NoRecordDeleteAlertSuppression")
    }
}

// MARK: - Helper Classes

class XAxisDateFormatter : IAxisValueFormatter {
    
    let dateFormatterDate = DateFormatter()
    let dateFormatterTime = DateFormatter()
    var lastDate = ""
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        dateFormatterDate.dateFormat = "M/d/yy"
        dateFormatterTime.dateFormat = "h:mm:ss"
        let date = dateFormatterDate.string(from:Date(timeIntervalSince1970: value))
        let time = dateFormatterTime.string(from:Date(timeIntervalSince1970: value))
        return "\(date)\n\(time)"
    }
}

class OximeterTableHeaderCell: NSTableHeaderCell {
    
    open override func titleRect(forBounds theRect: NSRect) -> NSRect {
        var titleFrame = super.titleRect(forBounds: theRect)
        let titleSize = self.attributedStringValue.size()
        // TODO: the +4 below is a hack
        titleFrame.origin.y = theRect.origin.y - 1.0 + (theRect.size.height - titleSize.height) / 2.0 + 4
        return titleFrame
    }
    
    open override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let titleRect = self.titleRect(forBounds: cellFrame)
        self.attributedStringValue.draw(in: titleRect)
    }
}

class OximeterPersonCellView: NSTableCellView {
    @IBOutlet weak var personPopup: NSPopUpButton!
}

class OximeterPopUpButton: NSPopUpButton {
    
    override func bind(_ binding: NSBindingName, to observable: Any, withKeyPath keyPath: String, options: [NSBindingOption : Any]? = nil) {
        
        var newOptions:[NSBindingOption:Any]?
        
        if options == nil {
            newOptions = [NSBindingOption:Any]()
        } else {
            if let _ = options {
                newOptions = options
            } else {
                newOptions = [NSBindingOption:Any]()
            }
        }
        newOptions![NSBindingOption.insertsNullPlaceholder] = true
        newOptions![NSBindingOption.nullPlaceholder] = "--"
        super.bind(binding, to: observable, withKeyPath: keyPath, options: newOptions)
    }
}
