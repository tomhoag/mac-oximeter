//
//  DownloadViewController.swift
//  Oximeter
//
//  Created by Tom on 4/12/20.
//  Copyright © 2020 SquarePi Software. All rights reserved.
//

import Cocoa

class DownloadViewController: NSViewController {
    
    enum DownloadState: Int {
        case initialize = 1
        case setup
        case download
        case done
        case errorNotFound
    }
    
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
    
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!
    
    @IBOutlet var stack:NSStackView!
    
    @IBAction func ok(_ sender:NSButton) {
        timer.invalidate()
        self.presentingViewController?.dismiss(self)
    }
    
    @IBAction func cancel(_ sender:NSButton) {
        timer.invalidate()
        self.presentingViewController?.dismiss(self)
    }
    
    @IBAction func download(_ sender:NSButton) { }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                             
        timer = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(self.timerFired(_:)), userInfo: nil, repeats: true)
        
        state = .initialize
        state = .setup
    }
    
    @objc fileprivate func timerFired(_ timer:Timer) {
        
        // advance the state
        switch(self.state) {
            
        case .initialize:
            self.state = .setup
            
        case .setup:
            self.state = .download
            setup.isHidden = true

        case .download:
            state = .done
            download.isHidden = true

        case .done:
            state = .errorNotFound
            done.isHidden = true
            
        case .errorNotFound:
            state = .setup
            error.isHidden = true
        }
    }
    
    dynamic var state:DownloadState = .errorNotFound {
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

            case .errorNotFound:
                stateString = "errorNotFound"
                
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
}
