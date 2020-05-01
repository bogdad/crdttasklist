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
