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


class OximeterViewController: NSViewController, OximeterDeviceDelegate {
    
    // MARK: - Bound Items

    @objc dynamic let serialPortManager = ORSSerialPortManager.shared()
    @objc dynamic let oximeter:OximeterDeviceController = OximeterDeviceController()

    @objc dynamic var chartTitle = ""
    @objc dynamic var connecting = false
    
    @objc dynamic var managedContext: NSManagedObjectContext!

    // MARK: - vars
    
    fileprivate var numberOfReports = 0
    
    // MARK: - Outlets & Actions
    @IBOutlet var reportArrayController: NSArrayController!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var reportTable: NSTableView!
    @IBOutlet weak var chartView: LineChartView!
    
    fileprivate var connectTries = 0
    fileprivate let maxConnectTries = 5
    
    @IBAction func connect(_ sender: Any) {
        
        guard ORSSerialPortManager.shared().availablePorts.count > 0 else {
            // TODO: pop up alerts?
            print("No Availble Devices")
            return
        }
                
        connectTries = 0
        // leverage the delegate response to bootstrap the search and connect
        connecting = true
        didConnect(port: nil, success: false)
    }
    
    // MARK: - ViewController
    
    required init?(coder: NSCoder) {
        super.init(coder:coder)
        print("init(coder: )")
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else {
          return
        }
        managedContext = appDelegate.persistentContainer.viewContext
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // Do any additional setup after loading the view.
        oximeter.delegate = self
        
        reportArrayController.addObserver(self, forKeyPath: "selectedObjects", options: .new, context: nil)

        chartView.noDataText = "Select a report above"
        chartView.backgroundColor = NSUIColor.white
        chartView.legend.font = NSUIFont(name: "HelveticaNeue-Light", size: CGFloat(14.0))!
        chartView.xAxis.valueFormatter = XAxisDateFormatter()
                
        tableView.tableColumns.forEach { (column) in // why can't this be done in the storyboard??
            let exAttr = NSMutableAttributedString(attributedString: column.headerCell.attributedStringValue)
            exAttr.replaceFont(with: NSFont.systemFont(ofSize: 16))
            
            let oxc = OxTextFieldCell()
            oxc.attributedStringValue = exAttr
            column.headerCell = oxc
        }
        
        var dummy = OximeterReport()
        dummy.header = "200328205541012200B4"
        saveReport(oxreport: dummy)
        dummy.data = "5e00385e00375e00375e00375e00375e00375e00375e00385e00385e00395e00395e00395f003a5f003a5f003a5f00395e00385e00375f00375f00365f00365f00375f00375f00385f00385f00385f00395e00395f00395f00395f00395f00385f00375f00375f00375f00375f00385f00395f00395f00385f00385f00395f00395f00385f00385f00375f00375f00375f00375f00375f00385f00395f00395f00395f00395f00395f00385f00385f00385f00385f00385f00385f00385f00375f00375f00375f00375f00375f00385f00395e00395e00395e00395d00385d00385d00385e00385e00395e00395f00395f003a5f003a5f003a"
        saveReport(oxreport: dummy)
        
        dummy = OximeterReport()
        dummy.header = "20032720280201420078"
        saveReport(oxreport: dummy)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    // MARK: - Charts
    
    func chartUpdate(_ report:Report) {
        
        guard report.data != "" else {
            // TODO: pop alert
            print("report missing data")
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
    

    // Select Table View > Bindings inspector > Selection Indexes > Bind to the Array Controller
    // Set Controller Key to selectionIndexes
    // To observe the selected objects, set up observation in viewDidLoad
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else { return }
        switch keyPath {

        case "selectedObjects":

            if let arrayController = object as? NSArrayController {
                let reports = arrayController.selectedObjects
       
                if let selected = reports![0] as? Report {
                    if let _ = selected.data {
                        chartUpdate(selected)
                    } else {
                        chartView.clear()
                    }
                }
            }

        default: break
        }
    }
    
    
    // MARK: - OximeterDeviceController Delegate
    
    func didConnect(port:ORSSerialPort?, success:Bool) {
        
        let availablePorts = ORSSerialPortManager.shared().availablePorts
        if success {
            print("yay! \(port) ready to go yo")
            connecting = false
            oximeter.getNumberOfReports()
        } else {
            print("sad trombone :( \(port) couldn't be opened")
            // get the next available port and try again
            var matchThis = ""
            if let port = port {
                matchThis = port.name
            }
            if let index = availablePorts.firstIndex(where: {$0.name == matchThis}) {
                if(index+1 < availablePorts.count) {
                    let nextPort = availablePorts[index+1]
                    oximeter.connect(using: nextPort)
                } else {
                    print("tried them all, no beuno!! \(connectTries)")
                    connectTries = connectTries + 1
                    if(connectTries < maxConnectTries) {
                        didConnect(port: nil, success: false)
                    } else {
                        print("tried to connect \(maxConnectTries) times -- no beuno")
                        connecting = false
                    }
                }
            } else {
                oximeter.connect(using: availablePorts[0])
            }
        }
    }
    
    func didGetNumberOfReports(numberOfReports: Int) {
        print("number of reports: \(numberOfReports)")
        self.numberOfReports = numberOfReports
        oximeter.getReportHeader(reportNumber: 1)
    }
    
    func didGetReportHeader(report: OximeterReport) {
        
//        saveReport(oxreport: report)
        oximeter.getReportData(reportNumber: report.number)
        
        print("didGetReportHeader: \(report.number)")
        if report.number < self.numberOfReports {
            oximeter.getReportHeader(reportNumber: report.number+1)
        }
    }
    
    func didGetReportData(report: OximeterReport) {
        saveReport(oxreport: report)
//        chartUpdate(report)
    }
    
    func couldNotCompleteRequest(message: String?) {
        print("device could not complete request: \(message!)")
    }
    
    // MARK: - Core Data
    func saveReport(oxreport: OximeterReport) {
        
        let entity = NSEntityDescription.entity(forEntityName: "Report", in: managedContext)!
        
        let report = NSManagedObject(entity: entity, insertInto: managedContext)
        managedContext.mergePolicy =  NSMergeByPropertyObjectTrumpMergePolicy
        
        report.setValue(oxreport.header, forKeyPath: "header")
        if let data = oxreport.data {
            report.setValue(data, forKeyPath: "data")
        }
        
        do {
            try managedContext.save()

        } catch let error as NSError {
            print(">>>> Could not save. \(error), \(error.userInfo) \(error.localizedDescription)")
        }
        
        print("saved \(oxreport.header)")
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

class OxTextFieldCell: NSTableHeaderCell {
    
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
