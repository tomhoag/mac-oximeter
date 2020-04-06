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

extension String {
    func substring(from: Int, to: Int) -> String {
        let start = index(startIndex, offsetBy: from)
        let end = index(start, offsetBy: to - from)
        return String(self[start ..< end])
    }

    func substring(range: NSRange) -> String {
        return substring(from: range.lowerBound, to: range.upperBound)
    }
}

class OximeterReport:NSObject {
    @objc var number:Int = 0
    @objc var header:String = ""
    @objc var data:String = ""
    
    let dateFormatterGet = DateFormatter()
    let dateFormatterPrint = DateFormatter()

    override init() {
        super.init()
        dateFormatterGet.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatterPrint.dateFormat = "MM/dd/yyy hh:mm:ss a"
    }
    
    var start:Date {
        get {
            if (14 > header.count) { return Date() }
            let year = header.substring(from: 0, to: 2)
            let month = header.substring(from: 2, to: 4)
            let day = header.substring(from:4, to: 6)
            let hour = header.substring(from:6, to: 8)
            let min = header.substring(from:10, to: 12)
            let sec = header.substring(from:12, to: 14)
            // let readingInterval 14,16
            // let mode 16, 18
            // let i1 = 18, 20
            // let i2 = 20, 22
            
            if let date = dateFormatterGet.date(from: "20\(year)-\(month)-\(day) \(hour):\(min):\(sec)") {
                return date
            } else {
                return Date()
            }
        }
    }
    
    var end:Date {
        // response: 01 23 45 67 89 AB CD EF
        // response: YY MM DD HH MM SS RR MO 00 B4
        // response: YY MM DD HH MM SS RR MD II JJ
        get {
            let readingInterval = Int(header.substring(from:12, to:14), radix:16)!
            let delta = Int(header.substring(from:16, to:20), radix:16)!
            // =((HEX2DEC(M4)*256+hex2dec(N4))/3 * K4)-K4
            let interval:TimeInterval = TimeInterval((delta/3 * readingInterval) - readingInterval)
            return start.addingTimeInterval(interval)
        }
    }
    
    @objc var startDate:String {
        get {
            return dateFormatterPrint.string(from:start)
        }
    }
    
    @objc var endDate:String {
        get {
            return dateFormatterPrint.string(from:end)
        }
    }
    
    @objc var timingInterval:String {
        get {
            return "\(header.substring(from:12, to:14))s"
        }
    }
    
    @objc var mode:String {
        get {
            // 0x22 (34d) Adult, 0x42 (66) Pediatric
            let m = Int(header.substring(from:14, to:16), radix:16)
            if (34 == m) {
                return "Adult"
            } else if (66 == m) {
                return "Ped"
            } else {
                return "Unk"
            }
        }
    }
    
    @objc var sp02:[Int] {
        get {
            // sp 00 pr sp 00 pr sp 00 pr sp
            // 00 00 00 00 00 11 11 11 11 11
            // 01 23 45 67 89 01 23 45 67 89
            // 5e 00 32 5e 00 37 5f 00 34 38 . . .
            let pairs = data.pairs
            return pairs.enumerated().compactMap { tuple in
                tuple.offset.isMultiple(of: 3) ? Int(tuple.element, radix:16) : nil
            }
        }
    }
    
    @objc var pulse:[Int] {
        get {
            var pairs = data.pairs
            pairs.removeFirst()
            pairs.removeFirst()
            return pairs.enumerated().compactMap { tuple in
                tuple.offset.isMultiple(of: 3) ? Int(tuple.element, radix:16) : nil
            }
        }
    }

}

extension Collection {
    var pairs: [SubSequence] {
        var startIndex = self.startIndex
        let count = self.count
        let n = count/2 + count % 2
        return (0..<n).map { _ in
            let endIndex = index(startIndex, offsetBy: 2, limitedBy: self.endIndex) ?? self.endIndex
            defer { startIndex = endIndex }
            return self[startIndex..<endIndex]
        }
    }
}

protocol OximeterDeviceDelegate {
    
    func reportDidComplete(report:OximeterReport)
}

class OximeterDeviceController: NSObject, ORSSerialPortDelegate {
    
    override init() {
        super.init()
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
        nextCommandFunction(reportIndex)
    }
    
    // MARK: Sending Commands
    fileprivate func handshake(unused:Int) {
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
    
    fileprivate func getNumberOfReports(unused:Int) {
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
    
    fileprivate func getReportHeader(index:Int) {
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
            
            reportIndex = reportIndex + 1
            if(reportIndex > numberOfReports) {
                pollingTimer?.invalidate()
            }
            
        case .getReportData:

            let length = responseData.count - 3
            var data = responseData.subdata(in:0..<length)
            data = responseData.subdata(in:3..<length)
            reports[reportIndex].data = data.hexDescription
            
            delegate?.reportDidComplete(report: reports[reportIndex])
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
                port.baudRate = 38400
                port.parity = .none
                port.numberOfStopBits = 1
                port.delegate = self
//                port.rts = true
                port.open()
            }
        }
    }
    
//    @objc dynamic fileprivate(set) internal var temperature: Int = 0
//
//    @objc dynamic fileprivate var internalLEDOn = false
//
//    class func keyPathsForValuesAffectingLEDOn() -> NSSet { return NSSet(object: "internalLEDOn") }
//    @objc dynamic var LEDOn: Bool {
//        get {
//            return internalLEDOn
//        }
//        set(newValue) {
//            internalLEDOn = newValue
//            sendCommandToSetLEDToState(newValue)
//        }
//    }
//
    fileprivate var pollingTimer: Timer? {
        willSet {
            if let timer = pollingTimer {
                timer.invalidate()
            }
        }
    }
}
