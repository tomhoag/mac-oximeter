//
//  CollectionExtension.swift
//  Oximeter
//
//  Created by Tom on 4/6/20.
//  Copyright © 2020 SquarePi Software. All rights reserved.
//

import Foundation

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
