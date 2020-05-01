//
//  Breaks.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 7/7/19.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//
//  Its actually a direct translation of View from
//  https://github.com/xi-editor/xi-editor/blob/master/rust/rope/src/breaks.rs
//  to Swift
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

struct BreaksLeaf: Leaf {

    let MIN_LEAF: UInt = 32
    let MAX_LEAF: UInt = 64

    /// Length, in base units.
    var _len: UInt
    /// Indexes, represent as offsets from the start of the leaf.
    var data: [UInt]

    static func def() -> BreaksLeaf {
        return BreaksLeaf(_len: 0, data: [])
    }

    func len() -> UInt {
        return _len
    }

    func is_ok_child() -> Bool {
        return self.data.count >= MIN_LEAF
    }

    mutating func push_maybe_split(other: inout BreaksLeaf, iv: Interval) -> BreaksLeaf? {
         let (start, end) = iv.start_end()
         for v in other.data {
             if start < v && v <= end {
                 self.data.append(v - start + self._len)
             }
         }
         // the min with other.len() shouldn't be needed
         self._len += min(end, other.len()) - start

         if self.data.count <= MAX_LEAF {
            return nil
         } else {
            let splitpoint = self.data.count / 2 // number of breaks
            let splitpoint_units = self.data[splitpoint - 1]

            var new = Array(self.data.suffix(from: splitpoint))
            for i in new.indices {
                 new[i] -= splitpoint_units
            }
            let new_len = self._len - splitpoint_units
            self._len = splitpoint_units
            return BreaksLeaf(_len: new_len, data: new)
         }
    }
}


struct BreaksInfo: NodeInfo {
    typealias L = BreaksLeaf

    typealias DefaultMetric = BreaksBaseMetric

    var _0: UInt

    mutating func accumulate(other: inout BreaksInfo) {
        self._0 += other._0
    }

    static func compute_info(leaf: inout BreaksLeaf) -> BreaksInfo {
        return BreaksInfo(_0: UInt(leaf.data.count))
    }
}

struct BreaksBaseMetric: Metric {
    typealias N = BreaksInfo

    static func measure(_ info: inout BreaksInfo, _ len: UInt) -> UInt {
        return len
    }

    static func to_base_units(_ l: inout BreaksInfo.L, _ in_measured_units: UInt) -> UInt {
        return in_measured_units
    }

    static func from_base_units(_ l: inout BreaksInfo.L, _ in_base_units: UInt) -> UInt {
        return in_base_units
    }

    static func is_boundary(_ l: inout BreaksInfo.L, _ offset: UInt) -> Bool {
        return BreaksMetric.is_boundary(&l, offset)
    }

    static func prev(_ l: inout BreaksInfo.L, _ offset: UInt) -> UInt? {
        return BreaksMetric.prev(&l, offset)
    }

    static func next(_ l: inout BreaksInfo.L, _ offset: UInt) -> UInt? {
        return BreaksMetric.next(&l, offset)
    }

    static func can_fragment() -> Bool {
        return true
    }
}

/// A set of indexes. A motivating use is storing line breaks.
typealias Breaks = Node<BreaksInfo>

struct BreaksMetric: Metric {
    typealias N = BreaksInfo
    static func measure(_ info: inout BreaksInfo, _ len: UInt) -> UInt {
        return info._0
    }

    static func to_base_units(_ l: inout BreaksInfo.L, _ in_measured_units: UInt) -> UInt {
        if in_measured_units > l.data.count {
            return l._len + 1
        } else if in_measured_units == 0 {
            return 0
        } else {
            return l.data[Int(in_measured_units) - 1]
        }
    }

    static func from_base_units(_ l: inout BreaksInfo.L, _ in_base_units: UInt) -> UInt {
        let (pos, found) = l.data.binary_search(in_base_units)
        if found {
            return UInt(pos + 1)
        } else {
            return UInt(pos)
        }
    }

    static func is_boundary(_ l: inout BreaksInfo.L, _ offset: UInt) -> Bool {
        return l.data.binary_search(offset).1
    }

    static func prev(_ l: inout BreaksInfo.L, _ offset: UInt) -> UInt? {
        for i in 0..<l.data.count {
            if offset <= l.data[i] {
                if i == 0 {
                    return nil
                } else {
                    return l.data[i - 1]
                }
            }
        }
        return l.data.last
    }

    static func next(_ l: inout BreaksInfo.L, _ offset: UInt) -> UInt? {
        let (pos, found) = l.data.binary_search(offset)
        var n: Int
        if found {
            n = pos + 1
        } else {
            n = pos
        }
        if n == l.data.count {
            return nil
        } else {
            return l.data[n]
        }
    }

    static func can_fragment() -> Bool {
        return true
    }
}


struct BreakBuilder {
    let MAX_LEAF: UInt = 64
    var b: TreeBuilder<BreaksInfo>
    var leaf: BreaksLeaf

    func def() -> BreakBuilder {
        return BreakBuilder()
    }

    init() {
        self.b = TreeBuilder()
        self.leaf = BreaksLeaf.def()
    }

    mutating func add_break(_  len: UInt) {
        if self.leaf.data.count == MAX_LEAF {
            self.b.push(n: Node.from_leaf(l: &leaf))
        }
        self.leaf._len += len;
        self.leaf.data.append(self.leaf.len())
    }

    mutating func add_no_break(_ len: UInt) {
        self.leaf._len += len
    }

    mutating func build() -> Breaks {
        self.b.push(n: Node.from_leaf(l: &self.leaf))
        return self.b.build()
    }
}
