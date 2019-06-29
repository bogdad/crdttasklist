//
//  Strings.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 5/25/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
//  This is the utilities needed by a direct translation of Rope from
//  https://github.com/xi-editor/xi-editor/blob/master/rust/rope/
//  to Swift
//
//
//
// Copyright 2016 The xi-editor Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
import Foundation

struct Utils {

    static func count_newlines(s: Substring) -> UInt {
        let ns = s as NSString
        var count:UInt = 0
        ns.enumerateLines { (str, _) in
            count += 1
        }
        return count
    }

    static func count_utf16_code_units(s: inout String) -> UInt {
        var utf16_count: UInt = 0
        for b in s.utf16 {
            if Int8(b) >= -0x40 {
                utf16_count += 1
            }
            if Int16(b) >= 0xf0 {
                utf16_count += 1
            }
        }
        return utf16_count
    }

    static func find_leaf_split_for_merge(s: Substring) -> UInt {
        return find_leaf_split(s: s, minsplit: max(RopeConstants.MIN_LEAF, s.len() - RopeConstants.MAX_LEAF))
    }

    static func find_leaf_split_for_bulk(s: Substring) -> UInt {
        return find_leaf_split(s: s, minsplit: RopeConstants.MIN_LEAF)
    }

    static func find_leaf_split(s: Substring, minsplit: UInt) -> UInt {
        var splitpoint = min(RopeConstants.MAX_LEAF, s.len() - RopeConstants.MIN_LEAF)
        let s_ind = String.Index(utf16Offset: Int(minsplit - 1), in: s)
        let e_ind = String.Index(utf16Offset: Int(splitpoint), in: s)
        let substr = s[s_ind..<e_ind]
        let res = substr.firstIndex(of: "\n")
        switch res {
        case .some(let rng):
            // TODO: find out if utf16Offset is safe to be called on substr and not on substr.utf16
            return minsplit + UInt(rng.utf16Offset(in: substr))
        case .none:
            while !s.is_char_boundary(index: splitpoint) {
                splitpoint -= 1
            }
            return splitpoint
        }
    }

    static func split_as_leaves(s: String) -> [String] {
        var nodes = [String]()
        var ss = s[s.startIndex..<s.endIndex]
        while !ss.isEmpty {
            let splitpoint = ss.count > RopeConstants.MAX_LEAF ? Utils.find_leaf_split_for_bulk(s: ss) : ss.len()
            let splitpoint_i: String.Index = String.Index(utf16Offset: Int(splitpoint), in: ss)
            let prefix = ss[..<splitpoint_i]
            nodes.append(String(prefix))
            ss.removeSubrange(..<splitpoint_i)
        }
        return nodes
    }

}

extension String {
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

    static func from(rope: Rope) {
        //r.slice_to_cow(..)
    }
}

extension Substring {
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
}

struct RangeFull: IntervalBounds {
    func into_interval(upper_bound: UInt) -> Interval {
        return Interval(0, upper_bound)
    }
}
