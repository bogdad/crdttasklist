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
    let backingStore: NSMutableAttributedString
    let crdt: CRDT

    override init() {
        self.crdt = CRDT("")
        self.backingStore = NSMutableAttributedString()
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var string: String {
        //print("string \(crdt.to_string())  \(backingStore.string)")
        return crdt.to_string()
    }

    override func attributes(
      at location: Int,
      effectiveRange range: NSRangePointer?
    ) -> [NSAttributedString.Key: Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        print("replaceCharactersInRange \(range) withString:\(str)")

        beginEditing()
        backingStore.replaceCharacters(in: range, with:str)
        replaceCharactersInRange(range, withText: str as NSString)

        edited(.editedCharacters, range: range,
             changeInLength: (str as NSString).length - range.length)
        endEditing()
    }

    override func insert(_ attrString: NSAttributedString, at loc: Int) {
        print("insert \(attrString) at loc: \(loc)")
        beginEditing()
        crdt.insert(chars: attrString.string)
        endEditing()
    }

    func replaceCharactersInRange(_ aRange: NSRange, withText aString: AnyObject) -> NSRange {
         var replacementRange = aRange
         var len = 0
         if let attrStr = aString as? NSAttributedString {
             len = attrStr.string.utf16.count
         } else if let str = aString as? NSString {
             len = str.length
         }
         if (replacementRange.location == NSNotFound) {
             replacementRange.location = 0
             replacementRange.length = 0
         }
         for _ in 0..<aRange.length {
             crdt.deleteBackward()
         }
         if let attrStr = aString as? NSAttributedString {
             crdt.insert(chars: attrStr.string)
         } else if let str = aString as? String {
             crdt.insert(chars: str)
         }
         return NSMakeRange(replacementRange.location, len)
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        print("setAttributes:\(String(describing: attrs?.keys)) range:\(range)")

        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

}
