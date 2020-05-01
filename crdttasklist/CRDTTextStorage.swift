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
    let backingStore: NSTextStorage
    let serialQueue = DispatchQueue(label: "crdt text storage queue", attributes: .concurrent)
    let controller: CRDTNoteViewController
    var _crdt: CRDT

    func crdt<R>(block: (inout CRDT) -> R) -> R {
        return serialQueue.sync(flags: .barrier) {
            return block(&_crdt)
        }
    }

    init(_ crdt: CRDT?, _ controller: CRDTNoteViewController) {
        self._crdt = crdt ?? CRDT("")
        self.backingStore = NSTextStorage(string: self._crdt.to_string())
        self.controller = controller
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var string: String {
        //return crdt { crdt in crdt.to_string() }
        return backingStore.string
    }

    override func attributes(
      at location: Int,
      effectiveRange range: NSRangePointer?
    ) -> [NSAttributedString.Key: Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with:str)
        replaceCharactersInRange(range, withText: str as NSString)
        edited([.editedCharacters, .editedAttributes], range: range,
             changeInLength: (str as NSString).length - range.length)
        endEditing()

    }

    func replaceCharactersInRange(_ aRange: NSRange, withText aString: AnyObject) {
        crdt { crdt in
            crdt.set_position(aRange.to_interval())
            for _ in 0..<aRange.length {
                crdt.deleteBackward()
            }
            if let attrStr = aString as? NSAttributedString {
               crdt.insert(attrStr.string)
            } else if let str = aString as? String {
               crdt.insert(str)
            }
            controller.textView?.selectedRange = NSRange.from_interval(crdt.position())
            print("after edit \(controller.textView?.selectedRange)")
         }
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

}
