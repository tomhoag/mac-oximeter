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

class OximeterViewController: NSViewController, NSTableViewDelegate, OximeterDeviceDelegate, DeviceFinderDelegate {
    
    func deviceFound(port: ORSSerialPort) {
        print("found device \(port)")
        
        boardController.serialPort = port
    }
    
    func noDeviceFound() {
        print("sad trombone")
    }
    

    @IBOutlet weak var reportTable: NSTableView!
    
    @IBOutlet weak var chartView: LineChartView!
    
    @objc dynamic let serialPortManager = ORSSerialPortManager.shared()
    @objc dynamic let boardController = OximeterDeviceController()
    
    @objc dynamic var chartTitle = ""

    
    @IBAction func connect(_ sender: Any) {
        let finder = DeviceFinder()
        finder.finderDelegate = self
        finder.findOximeterDevice()
    }
    
    var lastSelectedIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        reportTable.delegate = self
        boardController.delegate = self
        
        chartView.noDataText = "Select a report above"
        chartView.backgroundColor = NSUIColor.white
        chartView.legend.font = NSUIFont(name: "HelveticaNeue-Light", size: CGFloat(14.0))!
        
        chartView.xAxis.valueFormatter = XAxisDateFormatter()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func chartUpdate(_ report:OximeterReport) {
        
        let interval = Int(report.timingInterval)!
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


        chartTitle = "\(report.startDate)-\(report.endDate) Interval:\(report.timingInterval) Mode:\(report.mode)"
    }
    
    //  MARK: - reportTable Delegate
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        lastSelectedIndex = reportTable.selectedRow
        boardController.getReportData(index: lastSelectedIndex)
    }
    
    // MARK: - OximeterDeviceController Delegate
    
    func reportDidComplete(report: OximeterReport) {
        chartUpdate(report)
    }
}

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

