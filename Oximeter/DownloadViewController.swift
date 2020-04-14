//
//  DownloadViewController.swift
//  Oximeter
//
//  Created by Tom on 4/12/20.
//  Copyright © 2020 SquarePi Software. All rights reserved.
//

import Cocoa
import ORSSerial

class DownloadViewController: NSViewController, OximeterDeviceDelegate {
    
    enum DownloadState: Int {
        case initialize = 1
        case setup
        case download
        case done
        case error
    }
    
    @objc dynamic let serialPortManager = ORSSerialPortManager.shared()
    @objc dynamic let oximeter:OximeterDeviceController = OximeterDeviceController()
    @objc dynamic var connecting = false // used for animating the progress bar
    
    /// number of reports available on the device
    fileprivate var numberOfReports = 0
    /// number of times have iterated through available serial ports attempting to connect to the oximeter
    fileprivate var connectTries = 0
    /// maximum number of times to attempt to find and connect to the oximeter
    fileprivate let maxConnectTries = 5
    /// flag to indicate that user has cancelled connect
    fileprivate var connectCanceled = false
    
    var saveReportWithPerson:Person?
    
    @objc dynamic var managedContext: NSManagedObjectContext!
    
    fileprivate var timer:Timer!
    @objc dynamic var stateString = "setup"
    
    @IBOutlet weak var stateLabel:NSTextField!
    
    @IBOutlet weak var header:NSView!
    @IBOutlet weak var setup:NSView!
    @IBOutlet weak var download:NSView!
    @IBOutlet weak var error:NSView!
    @IBOutlet weak var done:NSView!
    @IBOutlet weak var buttons:NSView!
    @IBOutlet weak var downloadButton:NSButton!
    @IBOutlet weak var okButton:NSButton!
    @IBOutlet weak var cancelButton:NSButton!
    @IBOutlet weak var downloadCheckbox: NSButton!
    @IBOutlet weak var downloadPatientPopup: NSPopUpButton!
    @IBOutlet weak var disclosureButton:NSButton!
    @IBOutlet weak var disclosureLabel:NSTextField!
    @IBOutlet weak var disclosureHints:NSTextField!
    @IBOutlet weak var disclosureHeightConstraint:NSLayoutConstraint!
    @IBOutlet weak var errorHeightConstraint:NSLayoutConstraint!
    
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!
    
    @IBOutlet var personArrayController:NSArrayController!
    
    // MARK: - IBActions
    
    @IBAction func checkboxChanged(_ sender: NSButton) {
        downloadPatientPopup.isEnabled = sender.state == .off
    }
    
    @IBAction func disclosureChanged(_ sender: Any) {
        
        // if this was the button, state is already in its final state
        // if this was the label, invert the buttons state
        
        if let _ = sender as? NSTextField {
            if .on == disclosureButton.state {
               disclosureButton.state = .off
            } else {
                disclosureButton.state = .on
            }
        }
        
        var newHeight:CGFloat = 0.0
        if disclosureButton.state == .on {
            newHeight = disclosureHints.stringValue.heightWithConstrainedWidth(width: disclosureHints.frame.size.width, font: disclosureHints.font!)
        }
        
        NSAnimationContext.runAnimationGroup({ (context) in
            context.duration = 0.05
            context.completionHandler = {
                if self.disclosureButton.state == .off {
                    self.disclosureLabel.stringValue = "More Info"
                } else {
                    self.disclosureLabel.stringValue = "Hide"
                }
            }
            self.disclosureHeightConstraint.animator().constant = newHeight
        })
    }
    
    @IBAction func ok(_ sender:NSButton) {
        self.presentingViewController?.dismiss(self)
    }
    
    @IBAction func cancel(_ sender:NSButton) {
        
        self.connectCanceled = true
        if state != .download { // download will handle dismissal in didConnect
            self.presentingViewController?.dismiss(self)
        }
    }
    
    @IBAction func download(_ sender:NSButton) {
        state = .download
        if self.downloadCheckbox.state == .off {
            // get the selected person from the arrayController
            let persons = self.personArrayController.selectedObjects
            if persons!.count > 0 {
                if let selected = persons![0] as? Person {
                    self.saveReportWithPerson = selected
                }
            }
        }
        self.connect()
    }
    
    // MARK: - View Management

    override func viewDidLoad() {
        super.viewDidLoad()
        oximeter.delegate = self
        
        

        state = .initialize
//        state = .setup
        
        state = .error
    }
    
    required init?(coder: NSCoder) {
        super.init(coder:coder)
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else {
            return
        }
        managedContext = appDelegate.persistentContainer.viewContext
    }
    
    dynamic var state:DownloadState = .error {
        didSet {
            let duration = 0.25
            let headerHeight =  header.frame.size.height
            let buttonsHeight = buttons.frame.size.height
            let dp = CGPoint(x: 0, y: headerHeight)
            
            setup.isHidden = true
            download.isHidden = true
            error.isHidden = true
            done.isHidden = true
            
            switch(self.state) {
                
            case .initialize:
                
                downloadButton.isHidden = true
                cancelButton.isHidden = true
                okButton.isHidden = true
                self.heightConstraint.constant = header.frame.size.height + setup.frame.size.height + buttons.frame.size.height
                
            case .download:
                stateString = "download"
                
                NSAnimationContext.runAnimationGroup({ (context) in
                    context.duration = duration
                    context.completionHandler = {
                        self.download.setFrameOrigin(dp)
                        self.download.isHidden = false
                        
                        self.downloadButton.isHidden = true
                        self.cancelButton.isHidden = false
                        self.okButton.isHidden = true
                    }
                    self.heightConstraint.animator().constant = headerHeight + download.frame.size.height + buttonsHeight
                })
                
            case .done:
                stateString = "done"
                
                NSAnimationContext.runAnimationGroup({ (context) in
                    context.duration = duration
                    context.completionHandler = {
                        self.done.isHidden = false
                        self.done.setFrameOrigin(dp)
                        
                        self.downloadButton.isHidden = true
                        self.cancelButton.isHidden = true
                        self.okButton.isHidden = false
                    }
                    
                    self.heightConstraint.animator().constant = headerHeight + done.frame.size.height + buttonsHeight
                })
                
            case .error:
                stateString = "errorNotFound"
                
                disclosureButton.state = .off
                self.disclosureButton.state = .off
                self.disclosureLabel.stringValue = "More Info"
                self.disclosureHints.stringValue = "1. This\n2.  That\n3.  The other thing"
                self.disclosureHeightConstraint.constant = 0
                
                NSAnimationContext.runAnimationGroup({ (context) in
                    context.duration = duration
                    context.completionHandler = {
                        self.error.setFrameOrigin(dp)
                        self.error.isHidden = false
                        
                        self.downloadButton.isHidden = true
                        self.cancelButton.isHidden = true
                        self.okButton.isHidden = false
                    }
                    self.heightConstraint.animator().constant = headerHeight + error.frame.size.height + buttonsHeight
                })
                
                
            case .setup:
                stateString = "setup"
                
                NSAnimationContext.runAnimationGroup({ (context) in
                    context.duration = duration
                    context.completionHandler = {
                        self.setup.isHidden = false
                        self.setup.setFrameOrigin(dp)
                        
                        self.downloadButton.isHidden = false
                        self.cancelButton.isHidden = false
                        self.okButton.isHidden = true
                    }
                    self.heightConstraint.animator().constant = headerHeight + setup.frame.size.height + buttonsHeight
                })
            }
        }
    }
    
    // MARK: - Oximeter Connect & Download
    
    fileprivate func connect() {
        
        guard ORSSerialPortManager.shared().availablePorts.count > 0 else {
            
            let alert = NSAlert.init()
            alert.messageText = "No Serial Ports"
            alert.informativeText = "There are no serial ports to connect to."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.beginSheetModal(for: self.view.window!) { (response) in }
            return
        }
        
        connectTries = 0
        connecting = true
        connectCanceled = false
        // leverage the delegate response to bootstrap the search and connect
        didConnect(port: nil, success: false)
    }
    
    // MARK: - OximeterDeviceController Delegate
    
    func didConnect(port:ORSSerialPort?, success:Bool) {
        
        guard false == connectCanceled else {
            self.presentingViewController?.dismiss(self)
            return
        }
        
        let availablePorts = ORSSerialPortManager.shared().availablePorts
        if success {
            connecting = false
            oximeter.getNumberOfReports()
        } else {
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
                    connectTries = connectTries + 1
                    if(connectTries < maxConnectTries) {
                        didConnect(port: nil, success: false)
                    } else {
                        
                        connectCanceled = true
                        
                        state = .error
                        // TODO: setup the error message
                        //                        let alert = NSAlert.init()
                        //                        alert.messageText = "Could Not Connect"
                        //                        alert.informativeText = "An Oximeter could not be found.\n\nPlease check the connections and turn it on."
                        //                        alert.alertStyle = .informational
                        //                        alert.addButton(withTitle: "OK")
                        //                        alert.beginSheetModal(for: self.view.window!) { (response) in }
                        
                        connecting = false
                    }
                }
            } else {
                oximeter.connect(using: availablePorts[0])
            }
        }
    }
    
    func didGetNumberOfReports(numberOfReports: Int) {
        
        guard false == connectCanceled else {
            self.view.window!.endSheet(self.view.window!.sheets[0])
            return
        }
        
        self.numberOfReports = numberOfReports
        if numberOfReports > 0 {
            oximeter.getReportHeader(reportNumber: 1)
        }
    }
    
    func didGetReport(header: String, for reportNumber:Int) {
        let entity = NSEntityDescription.entity(forEntityName: "Report", in: managedContext)!
        let report = NSManagedObject(entity: entity, insertInto: managedContext) as? Report
        report!.setValue(header, forKeyPath: "header")
        oximeter.getReportData(reportNumber: reportNumber, userInfo:report!) // 1-based
    }
    
    func didGetReport(data: String, for reportNumber: Int, userInfo:Any?) {
        let report = userInfo as! Report
        report.setValue(data, forKeyPath: "data")
        
        if nil != saveReportWithPerson {
            report.person = self.saveReportWithPerson
        }
        saveReport(report)
        
        guard false == connectCanceled else {
            self.view.window!.endSheet(self.view.window!.sheets[0])
            return
        }
        
        if(reportNumber + 1 <= self.numberOfReports) {
            oximeter.getReportHeader(reportNumber: reportNumber+1)
        }
    }
    
    func couldNotCompleteRequest(message: String?) {
        print("device could not complete request: \(message!)")
    }
    
    // MARK: - Core Data
    func saveReport(_ report:Report) {
        
        managedContext.mergePolicy =  NSMergeByPropertyObjectTrumpMergePolicy
        do {
            try managedContext.save()
            
        } catch let error as NSError {
            print(">>>> Could not save. \(error), \(error.userInfo) \(error.localizedDescription)")
        }
    }
}

class OxView: NSView {
    override var isFlipped: Bool { get { return false }}
}
