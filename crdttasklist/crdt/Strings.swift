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
            if Int16(b) >= -0x40 {
                utf16_count += 1
            }
            if Int16(b) >= 0xf0 {
                utf16_count += 1
            }
        }
        return utf16_count
    }

    /// Given the inital byte of a UTF-8 codepoint, returns the number of
    /// bytes required to represent the codepoint.
    /// RFC reference : https://tools.ietf.org/html/rfc3629#section-4
    static func len_utf8_from_first_byte(_ s: Substring) -> UInt {
        if s.len() != 1 {
            fatalError("can only call on non empty strings")
        }
        return s.withCString({ body -> UInt in
            let b: UInt8 = UInt8(body.pointee)
            if b < 0x80 {
                return 1
            }
            if b < 0xe0 {
                return 2
            }
            if b < 0xf0 {
                return 3
            }
            return 4
        })
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
        let res = substr.memchr("\n")
        switch res {
        case .some(let i):
            // TODO: find out if utf16Offset is safe to be called on substr and not on substr.utf16
            return minsplit + i
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

    func byte_at(_ offset: UInt)  -> UInt8 {
        if self.utf8CString.endIndex >= offset {
            fatalError("read past end index")
        }
        return withCString({ body -> UInt8 in
            return UInt8(body.advanced(by: Int(offset)).pointee)
        })
    }

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
}

extension Character {

    func is_variation_selector() -> Bool {
        let c = self
        return (c >= "\u{FE00}" && c <= "\u{FE0F}") || (c >= "\u{E0100}" && c <= "\u{E01EF}")
    }

    func is_regional_indicator_symbol() -> Bool {
        return self >= "\u{1F1E6}" && self <= "\u{1F1FF}"
    }

    func is_emoji_modifier() -> Bool {
        return self >= "\u{1F3FB}" && self <= "\u{1F3FF}"
    }

    func is_emoji_combining_enclosing_keycap() -> Bool {
        return self == "\u{20E3}"
    }

    func is_emoji() -> Bool {
        return Character.is_in_asc_list(self, EMOJI_TABLE, 0, EMOJI_TABLE.count - 1)
    }

    func is_emoji_cancel_tag() -> Bool {
        return self == "\u{E007F}"
    }

    func is_keycap_base() -> Bool {
        let c = self
        return ("0" <= c && c <= "9") || c == "#" || c == "*"
    }

    func is_zwj() -> Bool {
        return self == "\u{200D}"
    }

    func is_emoji_modifier_base() -> Bool {
        return Character.is_in_asc_list(self, EMOJI_MODIFIER_BASE_TABLE, 0, EMOJI_MODIFIER_BASE_TABLE.count - 1)
    }

    func is_tag_spec_char() -> Bool {
        return "\u{E0020}" <= self && self <= "\u{E007E}"
    }

    static func is_in_asc_list<T: Comparable>(_ c: T, _ list: [T], _ start: Int, _ end: Int) -> Bool {
        if c == list[start] || c == list[end] {
            return true;
        }
        if end - start <= 1 {
            return false;
        }

        let mid = (start + end) / 2;

        if c >= list[mid] {
            return is_in_asc_list(c, list, mid, end)
        }
        return is_in_asc_list(c, list, start, mid)
    }
}
