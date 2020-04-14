//
//  OximeterDeviceController.swift
//  Oximeter
//
//  Created by Tom on 4/3/20.
//  Copyright © 2020 SquarePi Software. All rights reserved.
//
//    Permission is hereby granted, free of charge, to any person obtaining a
//    copy of this software and associated documentation files (the
//    "Software"), to deal in the Software without restriction, including
//    without limitation the rights to use, copy, modify, merge, publish,
//    distribute, sublicense, and/or sell copies of the Software, and to
//    permit persons to whom the Software is furnished to do so, subject to
//    the following conditions:
//
//    The above copyright notice and this permission notice shall be included
//    in all copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Cocoa
import ORSSerial

@objc protocol OximeterDeviceDelegate {
    
    @objc optional func didConnect(port:ORSSerialPort?, success:Bool)
    @objc optional func didGetNumberOfReports(numberOfReports:Int)
    @objc optional func didGetReport(header:String, for reportNumber:Int)
    @objc optional func didGetReport(data:String, for reportNumber:Int, userInfo:Any?)
    @objc optional func couldNotCompleteRequest(message:String?)
}

// MARK: -

class OximeterDeviceController: NSObject, ORSSerialPortDelegate {
    
    // MARK: Properties
       
    @objc internal var serialPort: ORSSerialPort? {
        willSet {
            if let port = serialPort {
                port.close()
                port.delegate = nil
            }
        }
        didSet {
            if let port = serialPort {
                port.baudRate = 38400
                port.parity = .none
                port.numberOfStopBits = 1
                port.delegate = self
                port.rts = true
                port.open()
            }
        }
    }
    
    fileprivate var waitTimer: Timer? {
        willSet {
            if let timer = waitTimer {
                timer.invalidate()
            }
        }
    }

    weak var delegate: OximeterDeviceDelegate?
    
    enum SerialBoardRequestType: Int {
        case open = 1
        case handshake
        case getNumberOfReports
        case getReportHeader
        case getReportData
    }
    
    struct SerialBoardRequest {
        var type:SerialBoardRequestType!
        var userInfo:Any?
        var reportNumber:Int?
    }
    
    struct WaitTimerInfo {
        var requestType:SerialBoardRequestType?
    }
        
    fileprivate let requestSuffix = "55AA0100"
    
    // MARK: - Connecting
    
    func connect(using port:ORSSerialPort) {
        serialPort = port // calls delegate.didConnect on success of open and handshake
        
        /// set a timer.  If the timer expires before didOpenSerialPort is called, no beuno for serialPort
        var userInfo = WaitTimerInfo()
        userInfo.requestType = SerialBoardRequestType.open
        waitTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.waitTimerFired(_:)), userInfo: userInfo, repeats: false)
    }
        
    fileprivate func handshake() {
        ///print("sending handshake");
        let command = Data(hexString:"55AA01")!
        let prefix:Data? = nil
        let suffix = Data(hexString:requestSuffix)!
        
        let responseDescriptor =  ORSSerialPacketDescriptor(prefix: prefix, suffix: suffix, maximumPacketLength: 10, userInfo: nil)
        var requestInfo = SerialBoardRequest()
        requestInfo.type = SerialBoardRequestType.handshake
        let request = ORSSerialRequest(dataToSend: command,
                                       userInfo: requestInfo,
                                       timeoutInterval: 0.5,
                                       responseDescriptor: responseDescriptor)
        
        if let port = serialPort {
            port.send(request)
        } else {
            delegate?.couldNotCompleteRequest?(message: "\(#function) serialPort is nil")
        }
    }
    
    // MARK: - Sending Commands

    func getNumberOfReports() {
        let opcode = "55AA02"
        let command = Data(hexString:opcode)!
        let prefix = Data(hexString:opcode)!
        let suffix = Data(hexString:requestSuffix)!
        let responseDescriptor =  ORSSerialPacketDescriptor(prefix: prefix, suffix: suffix, maximumPacketLength: 10, userInfo: nil)
        var requestInfo = SerialBoardRequest()
        requestInfo.type = SerialBoardRequestType.getNumberOfReports
        let request = ORSSerialRequest(dataToSend: command,
                                       userInfo: requestInfo,
                                       timeoutInterval: 0.5,
                                       responseDescriptor: responseDescriptor)
        
        if let port = serialPort {
            port.send(request)
        } else {
            delegate?.couldNotCompleteRequest?(message: "\(#function) serialPort is nil")
        }
    }
    
    func getReportHeader(reportNumber:Int) {

        let opcode = "55AA03"
        let command = Data(hexString: String(format:"\(opcode)%04X", reportNumber))! // 55 AA 03 00 01
        //print("sending: \(command.hexDescription) (from getReportHeader \(reportNumber))")
        
        let prefix = Data(hexString:opcode)!
        let suffix = Data(hexString:requestSuffix)!
        let responseDescriptor = ORSSerialPacketDescriptor(prefix: prefix, suffix: suffix, maximumPacketLength: 20, userInfo: nil)
        var requestInfo = SerialBoardRequest()
        requestInfo.type = SerialBoardRequestType.getReportHeader
        requestInfo.reportNumber = reportNumber
        let request = ORSSerialRequest(dataToSend: command,
                                       userInfo: requestInfo,
                                       timeoutInterval: 0.5,
                                       responseDescriptor: responseDescriptor)
        
        if let port = serialPort {
            port.send(request)
        } else {
            delegate?.couldNotCompleteRequest?(message: "\(#function) serialPort is nil")
        }
    }
    
    func getReportData(reportNumber:Int, userInfo:Any) {
                
        let opcode = "55AA04"
        let command = Data(hexString: String(format:"\(opcode)%04X", reportNumber))! // add 1 as device stores reports starting @ 1
        let prefix = Data(hexString:opcode)!
        let suffix = Data(hexString:requestSuffix)!
        
        let responseDescriptor = ORSSerialPacketDescriptor(prefix: prefix, suffix: suffix, maximumPacketLength: 4096, userInfo: nil)
        var requestInfo = SerialBoardRequest()
        requestInfo.type = SerialBoardRequestType.getReportData
        requestInfo.userInfo = userInfo
        requestInfo.reportNumber = reportNumber
        
        let request = ORSSerialRequest(dataToSend: command,
                                       userInfo: requestInfo,
                                       timeoutInterval: 0.5,
                                       responseDescriptor: responseDescriptor)
        
        if let port = serialPort {
            port.send(request)
        } else {
            delegate?.couldNotCompleteRequest?(message: "\(#function) serialPort is nil")
        }
    }
    
    // MARK: - ORSSerialPortDelegate
    
    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        self.serialPort = nil
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        //print("Serial port \(serialPort) encountered an error: \(error)")
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didReceiveResponse responseData: Data, to request: ORSSerialRequest) {
        
        let requestInfo = request.userInfo as! SerialBoardRequest

        let requestType = SerialBoardRequestType(rawValue:requestInfo.type.rawValue)!
        switch requestType {
        case .open:
            delegate?.didConnect?(port: serialPort, success: true)
        case .handshake:
            // Invalidate the timer and let the delegate know the device is good to go
            waitTimer?.invalidate()
            delegate?.didConnect?(port: serialPort, success: true)
            
        case .getNumberOfReports:
            let numberOfReports = UInt16(bigEndian: responseData.subdata(in: 3..<5).withUnsafeBytes { $0.load(as: UInt16.self) })
            delegate?.didGetNumberOfReports?(numberOfReports: Int(numberOfReports))
            
        case .getReportHeader:
            // response: 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15
            // response: 55 AA 03 YY MM DD HH MM SS RR MO 00 B4 55 AA 01
            var header = responseData.subdata(in:0..<13)
            header = header.subdata(in:3..<13)
            
            delegate?.didGetReport?(header: header.hexDescription, for:requestInfo.reportNumber!)
            
        case .getReportData:

            let length = responseData.count - 3
            var data = responseData.subdata(in:0..<length)
            data = responseData.subdata(in:3..<length)
            
            delegate?.didGetReport?(data: data.hexDescription, for: requestInfo.reportNumber!, userInfo:requestInfo.userInfo as Any)
        }
    }
    
    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        // change the timer userInfo
        waitTimer?.invalidate()
        var userInfo = WaitTimerInfo()
        userInfo.requestType = SerialBoardRequestType.handshake
        waitTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.waitTimerFired(_:)), userInfo: userInfo, repeats: false)
        
        handshake()
    }
    
    func serialPortWasClosed(_ serialPort: ORSSerialPort) { }
    
   
    
    // MARK: - The Waiting Timer
    
    @objc func waitTimerFired(_ timer: Timer) {
        //print("waitTimerFired: \(timer.userInfo as! WaitTimerInfo)")
        switch (timer.userInfo as! WaitTimerInfo).requestType {
        case .open:
            delegate?.didConnect?(port: serialPort!, success: false)
        case .handshake:
            delegate?.didConnect?(port: serialPort!, success:false)
        default:
            break
        }
    }
}


