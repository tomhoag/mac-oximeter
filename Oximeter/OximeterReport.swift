//
//  OximeterReport.swift
//  Oximeter
//
//  Created by Tom on 4/6/20.
//  Copyright © 2020 SquarePi Software. All rights reserved.
//

import Foundation

class OximeterReport:NSObject {
    @objc var number:Int = 0
    @objc var header:String = ""
    @objc var data:String = ""
    
    let dateFormatterGet = DateFormatter()
    let dateFormatterPrint = DateFormatter()

    override init() {
        super.init()
        dateFormatterGet.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatterPrint.dateFormat = "M/dd/yy h:mm:ss a"
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
    
    @objc var timingInterval:Int {
        get {
            return Int(header.substring(from:12, to:14))!
        }
    }
    
    @objc var mode:String {
        get {
            // 0x22 (34d) Adult, 0x42 (66) Pediatric
            let m = Int(header.substring(from:14, to:16), radix:16)
            if (34 == m) {
                return "Adult"
            } else if (66 == m) {
                return "Pediatric"
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
