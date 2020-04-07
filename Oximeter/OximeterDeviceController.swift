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

let kTimeoutDuration = 0.5


@objc protocol OximeterDeviceDelegate {
    
    @objc optional func didGetNumberOfReports(_ numberOfReports:Int)
    @objc optional func didGetReportHeader(report:OximeterReport)
    @objc optional func didGetReportData(report:OximeterReport)
}

class OximeterDeviceController: NSObject, ORSSerialPortDelegate {
    
    override init() {
        super.init()
    }
    
    convenience init(port:ORSSerialPort) {
        self.init()
        serialPort = port
    }
    
    var delegate: OximeterDeviceDelegate?

    @objc dynamic var reports = [OximeterReport]()
    
    enum SerialBoardRequestType: Int {
        case handshake = 1
        case getNumberOfReports
        case getReportHeader
        case getReportData
    }
    
    fileprivate var nextCommandFunction: ((Int) -> Void)!
    fileprivate var reportIndex:Int = 0
    fileprivate var numberOfReports:UInt16 = 0
    
    fileprivate let requestSuffix = "55AA0100"
    
    // MARK: - Private
    
    @objc func pollingTimerFired(_ timer: Timer) {
        print("firing \(String(describing: nextCommandFunction))")
//        nextCommandFunction(reportIndex)
    }
    
    // MARK: Sending Commands
   func handshake(unused:Int) {
        print("sending handshake");
        let command = Data(hexString:"55AA01")!
        let prefix:Data? = nil
        let suffix = Data(hexString:requestSuffix)!
        
        let responseDescriptor =  ORSSerialPacketDescriptor(prefix: prefix, suffix: suffix, maximumPacketLength: 10, userInfo: nil)
        let request = ORSSerialRequest(dataToSend: command,
                                       userInfo: SerialBoardRequestType.handshake.rawValue,
                                       timeoutInterval: 0.5,
                                       responseDescriptor: responseDescriptor)
        serialPort?.send(request)
    }
    
    func getNumberOfReports(unused:Int) {
        let opcode = "55AA02"
        let command = Data(hexString:opcode)!
        let prefix = Data(hexString:opcode)!
        let suffix = Data(hexString:requestSuffix)!
        let responseDescriptor =  ORSSerialPacketDescriptor(prefix: prefix, suffix: suffix, maximumPacketLength: 10, userInfo: nil)
        let request = ORSSerialRequest(dataToSend: command,
                                       userInfo: SerialBoardRequestType.getNumberOfReports.rawValue,
                                       timeoutInterval: 0.5,
                                       responseDescriptor: responseDescriptor)
        serialPort?.send(request)
    }
    
    func getReportHeader(index:Int) {
        let opcode = "55AA03"
        let command = Data(hexString: String(format:"\(opcode)%04X", index))! // 55 AA 03 00 01
        print("sending \(command.hexDescription) (getReportHeader \(index)")

        let prefix = Data(hexString:opcode)!
        let suffix = Data(hexString:requestSuffix)!
        let responseDescriptor = ORSSerialPacketDescriptor(prefix: prefix, suffix: suffix, maximumPacketLength: 20, userInfo: nil)
        let request = ORSSerialRequest(dataToSend: command,
                                       userInfo: SerialBoardRequestType.getReportHeader.rawValue,
                                       timeoutInterval: 0.5,
                                       responseDescriptor: responseDescriptor)
        serialPort?.send(request)
    }
    
    func getReportData(index:Int) {
        
        reportIndex = index
        
        let opcode = "55AA04"
        let command = Data(hexString: String(format:"\(opcode)%04X", index+1))! // add 1 as device stores reports starting @ 1
        let prefix = Data(hexString:opcode)!
        let suffix = Data(hexString:requestSuffix)!
        
        let responseDescriptor = ORSSerialPacketDescriptor(prefix: prefix, suffix: suffix, maximumPacketLength: 4096, userInfo: nil)
        let request = ORSSerialRequest(dataToSend: command,
                                       userInfo: SerialBoardRequestType.getReportData.rawValue,
                                       timeoutInterval: 0.5,
                                       responseDescriptor: responseDescriptor)
        serialPort?.send(request)
        
    }
    
    // MARK: - ORSSerialPortDelegate
    
    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        self.serialPort = nil
        print("removed")
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        print("Serial port \(serialPort) encountered an error: \(error)")
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didReceiveResponse responseData: Data, to request: ORSSerialRequest) {
        
        let requestType = SerialBoardRequestType(rawValue: request.userInfo as! Int)!
        switch requestType {
        case .handshake:
            print("handshake response: \(responseData.hexDescription)")
            nextCommandFunction = getNumberOfReports
            
        case .getNumberOfReports:
            print("numberOfReports: \(responseData.hexDescription) \(responseData[3...4].hexDescription)")
            
            numberOfReports = UInt16(bigEndian: responseData.subdata(in: 3..<5).withUnsafeBytes { $0.pointee })
            
            delegate?.didGetNumberOfReports?(Int(numberOfReports))
            
            print("numberOfReports: \(numberOfReports)")
            if(numberOfReports > 0) {
                reportIndex = 1
                nextCommandFunction = getReportHeader
            }
            
        case .getReportHeader:
            // response: 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15
            // response: 55 AA 03 YY MM DD HH MM SS RR MO 00 B4 55 AA 01
            var header = responseData.subdata(in:0..<13)
            header = header.subdata(in:3..<13)

            let report = OximeterReport()
            report.number = reportIndex
            report.header = header.hexDescription
            reports.append(report)
            
            delegate?.didGetReportHeader?(report: report)
            
            reportIndex = reportIndex + 1
            if(reportIndex > numberOfReports) {
                pollingTimer?.invalidate()
            }
            
        case .getReportData:

            let length = responseData.count - 3
            var data = responseData.subdata(in:0..<length)
            data = responseData.subdata(in:3..<length)
            reports[reportIndex].data = data.hexDescription
            
            delegate?.didGetReportData?(report: reports[reportIndex])
        }
    }
    
    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        
        nextCommandFunction = handshake
        
        self.pollingTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(OximeterDeviceController.pollingTimerFired(_:)), userInfo: nil, repeats: true)
        self.pollingTimer!.fire()
        
    }
    
    func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        self.pollingTimer = nil
    }
    
    // MARK: - Properties
    
    @objc fileprivate(set) internal var serialPort: ORSSerialPort? {
        willSet {
            if let port = serialPort {
                port.close()
                port.delegate = nil
            }
        }
        didSet {
            if let port = serialPort {
//                port.baudRate = 38400
//                port.parity = .none
//                port.numberOfStopBits = 1
//                port.delegate = self
//                port.rts = true
//                port.open()
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
