//
//  MoarExtensions.swift
//  Oximeter
//
//  Created by Tom on 4/7/20.
//  Copyright © 2020 SquarePi Software. All rights reserved.
//

import Cocoa

extension NSMutableAttributedString {
    func replaceFont(with font: NSFont) {
        beginEditing()
        self.enumerateAttribute(.font, in: NSRange(location: 0, length: self.length)) { (value, range, stop) in
            if let f = value as? NSFont {
                let ufd = f.fontDescriptor.withFamily(font.familyName!).withSymbolicTraits(f.fontDescriptor.symbolicTraits)
                let newFont = NSFont(descriptor: ufd, size: font.pointSize)
                removeAttribute(.font, range: range)
                addAttribute(.font, value: newFont as Any, range: range)
            }
        }
        endEditing()
    }
}


