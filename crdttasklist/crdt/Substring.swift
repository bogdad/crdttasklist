//
//  Substring.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-01.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation


extension Substring {
    func uintO(_ start: UInt, _ end: UInt) -> Substring {
        let s_i = String.Index(utf16Offset: Int(start), in: self)
        let e_i = String.Index(utf16Offset: Int(end), in: self)
        return self[s_i..<e_i]
    }
    func uintC(_ start: UInt, _ end: UInt) -> Substring {
        let s_i = String.Index(utf16Offset: Int(start), in: self)
        let e_i = String.Index(utf16Offset: Int(end), in: self)
        return self[s_i...e_i]
    }
    func memchr(_ char: Character) -> UInt? {
        return self.firstIndex(of: char)
            .map {UInt($0.utf16Offset(in: self))}
    }
    func is_char_boundary(index: UInt) -> Bool {
        // 0 and len are always ok.
        // Test for 0 explicitly so that it can optimize out the check
        // easily and skip reading string data for that case.
        if index == 0 || index == self.len() {
            return true
        }
        if index > self.len() {
            return false
        }
        var res = true
        self.withCString {
            ( bytes : (UnsafePointer<CChar>) ) -> Void in
            res = bytes[Int(index)] >= -0x40
        }
        return res
    }

    func len() -> UInt {
        return UInt(self.count)
    }

    func chars() -> [Int8] {
        var res = [Int8] (repeating: 0, count: count)
        self.withCString({ body in
            var i = 0
            while i < count {
                res[i] = body[i]
                i+=1
            }
        })
        return res
    }

    var lines: [String] {
        return self.components(separatedBy: "\n")
    }

    func count_newlines() -> UInt {
        let nl: Character = "\n"

        return UInt(data(using: .utf8)!
        .filter { $0 == nl.asciiValue! }
        .count)
    }
}
