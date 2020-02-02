//
//  CRDTTextStorage.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-02-02.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import UIKit

class CRDTTextStorage: NSTextStorage {
    let backingStore = NSMutableAttributedString()

    override var string: String {
        return backingStore.string
    }

    override func attributes(
      at location: Int,
      effectiveRange range: NSRangePointer?
    ) -> [NSAttributedString.Key: Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        print("replaceCharactersInRange:\(range) withString:\(str)")

        beginEditing()
        backingStore.replaceCharacters(in: range, with:str)
        edited(.editedCharacters, range: range,
             changeInLength: (str as NSString).length - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        print("setAttributes:\(String(describing: attrs)) range:\(range)")

        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

}
