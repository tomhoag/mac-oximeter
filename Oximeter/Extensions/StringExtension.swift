//
//  StringExtension.swift
//  Oximeter
//
//  Created by Tom on 4/6/20.
//  Copyright © 2020 SquarePi Software. All rights reserved.
//

import Foundation

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
