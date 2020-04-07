//
//  DeviceFinder.swift
//  Oximeter
//
//  Created by Tom on 4/6/20.
//  Copyright © 2020 SquarePi Software. All rights reserved.
//

import Cocoa
import ORSSerial

protocol DeviceFinderDelegate: class {
    
    func deviceFound(port:ORSSerialPort)
    
    func noDeviceFound()
    
}

class DeviceFinder: NSObject, ORSSerialPortDelegate {
    
    private var currentPortIndex:Int = -1
    private var availablePorts:[ORSSerialPort] = ORSSerialPortManager.shared().availablePorts
    
    var finderDelegate:DeviceFinderDelegate?
    
    override init() {
        super.init()
    }
    
    func findOximeterDevice() {
        self.pollingTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(DeviceFinder.pollingTimerFired(_:)), userInfo: nil, repeats: false)
        self.pollingTimer!.fire()
    }
    
    @objc func pollingTimerFired(_ timer: Timer) {

        if let port = currentPort {
            print("time's up for \(port)!!")
            port.close()
        }
        
        currentPortIndex = currentPortIndex + 1
        
        if(currentPortIndex >= availablePorts.count) {
            pollingTimer?.invalidate()
            finderDelegate?.noDeviceFound()
            return
        }
        
        print("trying: \(availablePorts[currentPortIndex])")
        self.pollingTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(DeviceFinder.pollingTimerFired(_:)), userInfo: nil, repeats: false)
        currentPort = availablePorts[currentPortIndex]
    }
    
    // MARK: Sending Commands
    
    fileprivate func handshake() {
        print("sending handshake");
        let command = Data(hexString:"55AA01")!
        let prefix:Data? = nil
        let suffix = Data(hexString:"55AA0100")!
        
        let responseDescriptor =  ORSSerialPacketDescriptor(prefix: prefix, suffix: suffix, maximumPacketLength: 20, userInfo: nil)
        let request = ORSSerialRequest(dataToSend: command,
                                       userInfo: nil,
                                       timeoutInterval: 1.0,
                                       responseDescriptor: responseDescriptor)
        currentPort!.send(request)
    }
    
    // MARK: - ORSSerialPortDelegate
    
    func serialPort(_ serialPort: ORSSerialPort, requestDidTimeout request: ORSSerialRequest) {
        print("serial port request timed out: \(serialPort)")
    }
    
    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        handshake()
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didReceiveResponse responseData: Data, to request: ORSSerialRequest) {
        self.pollingTimer?.invalidate()

        currentPort?.delegate = nil
        finderDelegate?.deviceFound(port: currentPort!)
    }

    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) { }
    
    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        print("Serial port \(serialPort) encountered an error: \(error)   current: \(currentPort)")
    }
    
    func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        self.pollingTimer = nil
    }
    
    // MARK: - Properties
    
    @objc fileprivate(set) internal var currentPort: ORSSerialPort? {
        willSet {
            if let port = currentPort {
                port.close()
                port.delegate = nil
            }
        }
        didSet {
            if let port = currentPort {
                port.baudRate = 38400
                port.parity = .none
                port.numberOfStopBits = 1
                port.delegate = self
                port.open()
            }
        }
    }
    
    fileprivate var pollingTimer: Timer? {
        willSet {
            if let timer = pollingTimer {
                timer.invalidate()
            }
        }
    }
    
}
