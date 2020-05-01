//
//  String.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-03-28.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

extension String {

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

    func byte_at(_ offset: UInt)  -> UInt8 {
        if offset >= self.len() {
            fatalError("read past end index len \(self.len()) offset \(offset)")
        }
        return withCString({ body -> UInt8 in
            return UInt8(body.advanced(by: Int(offset)).pointee)
        })
    }

    func at(_ i: UInt) -> Character {
        return self[String.Index(utf16Offset: Int(i), in: self)]
    }

    func uintO(_ start: UInt, _ end: UInt) -> Substring {
        let s_i = String.Index(utf16Offset: Int(start), in: self)
        let e_i = String.Index(utf16Offset: Int(end), in: self)
        return self[s_i..<e_i]
    }
    func substr_starting(_ start: UInt) -> Substring {
        let s_i = String.Index(utf16Offset: Int(start), in: self)
        return self[s_i...]
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

}


extension String: Leaf {
    static func def() -> String {
        return ""
    }

    func is_ok_child() -> Bool {
        return self.len() >= RopeConstants.MIN_LEAF
    }

    mutating func push_maybe_split(other: inout String, iv: Interval) -> String? {
        let (start, end) = iv.start_end()
        self.append(contentsOf: other.uintO(start, end))
        if self.len() <= RopeConstants.MAX_LEAF {
            return Optional.none
        } else {
            let splitpoint = Utils.find_leaf_split_for_merge(s: self[...])
            let splitpoint_i = String.Index(utf16Offset: Int(splitpoint), in: self)
            let right_str = String(self[splitpoint_i...])
            self.removeSubrange(self.startIndex...splitpoint_i)
            //self.shrink_to_fit()
            return Optional.some(right_str)
        }
    }

    func len() -> UInt {
        return UInt(self.count)
    }

    func is_char_boundary(_ index: UInt) -> Bool {
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

    static func from(rope: Rope) -> String {
        return rope.to_string()
    }
}
