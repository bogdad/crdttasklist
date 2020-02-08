//
//  Rope.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 5/25/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
//  Its actually a direct translation of Rope from
//  https://github.com/xi-editor/xi-editor/blob/master/rust/rope/src/rope.rs
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
import IteratorTools

struct Constants {
    static let MIN_CHILDREN = 4
    static let MAX_CHILDREN = 8
    static let CURSOR_CACHE_SIZE = 4;
}

struct RopeConstants {
    static let MIN_LEAF: UInt = 511;
    static let MAX_LEAF: UInt = 1024;
}

struct Interval: Equatable, IntervalBounds {
    func into_interval(upper_bound: UInt) -> Interval {
        return self
    }

    var start: UInt
    var end: UInt
    init(_ start: UInt, _ end: UInt) {
        assert(start <= end)
        self.start = start
        self.end = end
    }

    func is_empty() -> Bool {
        return end <= start
    }

    static func == (lhs: Interval, rhs: Interval) -> Bool {
        return lhs.start == rhs.start && lhs.end == rhs.end
    }

    func is_before(val: UInt) -> Bool {
        return end <= val
    }

    func intersect(other: Interval) -> Interval {
        let start = max(self.start, other.start)
        let end = min(self.end, other.end)
        return Interval(start, max(start, end))
    }

    func translate(amount: UInt) -> Interval {
        return Interval(start + amount, end + amount)
    }

    func translate_neg(amount: UInt) -> Interval {
        assert(start >= amount)
        return Interval(start - amount, end - amount)
    }

    func start_end() -> (UInt, UInt) {
        return (self.start, self.end)
    }
}

protocol Leaf : Equatable, Codable {
    static func def() -> Self
    func len() -> UInt
    func is_ok_child() -> Bool
    mutating func push_maybe_split(other: inout Self, iv: Interval) -> Self?
}

extension Leaf {
    mutating func subseq(iv: Interval) -> Self {
        var result = type(of: self).def()
        let is_good = result.push_maybe_split(other: &self, iv: iv)
        // should consume everything
        if is_good != nil {
            fatalError("unexpected split")
        }
        return result
    }
}






protocol Metric {
    associatedtype N: NodeInfo
    static func measure(info: inout N, len: UInt) -> UInt
    static func to_base_units(l: inout N.L, in_measured_units: UInt) -> UInt
    static func from_base_units(l: inout N.L, in_base_units: UInt) -> UInt
    static func is_boundary(l: inout N.L, offset: UInt) -> Bool
    static func prev(l: inout N.L, offset: UInt) -> UInt?
    static func next(l: inout N.L, offset: UInt) -> UInt?
    static func can_fragment() -> Bool
}

struct RopeInfo: NodeInfo {
    typealias L = String

    var lines: UInt
    var utf16_size: UInt

    mutating func accumulate(other: inout RopeInfo) {
        self.lines += other.lines
        self.utf16_size += other.utf16_size
    }

    static func compute_info(leaf s: inout String) -> RopeInfo {
        return RopeInfo(
            lines: Utils.count_newlines(s: s[...]),
            utf16_size: Utils.count_utf16_code_units(s: &s))
    }

    func encode(with coder: NSCoder, forKey: String) {
        coder.encode(lines, forKey: "\(forKey).\(PropertyKey.lines)")
        coder.encode(utf16_size, forKey: "\(forKey).\(PropertyKey.utf16_size)")
    }

    static func decode(coder: NSCoder, forKey: String) -> RopeInfo? {
        guard let lines = coder.decodeObject(forKey: "\(forKey).\(PropertyKey.lines)") as? UInt,
            let utf16_size = coder.decodeObject(forKey: "\(forKey).\(PropertyKey.utf16_size)") as? UInt
        else {
        return nil
        }
        return RopeInfo(lines: lines, utf16_size: utf16_size)
    }

    struct PropertyKey {
        static let lines = "lines"
        static let utf16_size = "utf16_size"
    }
}

struct LinesMetric: Metric {
    static func measure(info: inout RopeInfo, len: UInt) -> UInt {
        return info.lines
    }

    static func to_base_units(l: inout String, in_measured_units: UInt) -> UInt {
        var offset:UInt = 0;
        for _ in 0...in_measured_units {
            let s_ind = String.Index(utf16Offset: Int(offset), in: l)
            let substr = l[s_ind...]
            let res = substr.firstIndex(of: "\n")
            switch res {
            case .some(let pos):
                offset += UInt(pos.utf16Offset(in: substr)) + 1
            default:
                fatalError("to_base_units called with arg too large")
            }
        }
        return offset
    }

    static func from_base_units(l: inout String, in_base_units: UInt) -> UInt {
        return Utils.count_newlines(s:l[...String.Index(utf16Offset: Int(in_base_units), in: l)])
    }

    static func is_boundary(l: inout String, offset: UInt) -> Bool {
        if offset == 0 {
            // shouldn't be called with this, but be defensive
            return false
        } else {
            return l[String.Index(utf16Offset: Int(offset - 1), in: l)] == "\n"
        }
    }

    static func prev(l: inout String, offset: UInt) -> UInt? {
        assert(offset > 0, "caller is responsible for validating input")
        let substr = l[...String.Index(utf16Offset: Int(offset), in: l)]
        return substr.firstIndex(of: "\n").map({ (pos:Substring.Index) -> UInt in
            return UInt(pos.utf16Offset(in: substr) + 1)
        })
    }

    static func next(l: inout String, offset: UInt) -> UInt? {
        let substr = l[String.Index(utf16Offset: Int(offset), in: l)...]
        return substr.firstIndex(of: "\n").map({ (pos:Substring.Index) -> UInt in
            return UInt(pos.utf16Offset(in: substr) + 1)
        })
    }

    static func can_fragment() -> Bool {
        return true
    }

    typealias N = RopeInfo

    // number of lines
    var val: UInt

    init() {
        val = 0
    }

}

protocol IntervalBounds {
    func into_interval(upper_bound:UInt) -> Interval
}


typealias Rope = Node<RopeInfo>

extension Rope {

    static func from_str(_ s: Substring) -> Rope {
        var b = TreeBuilder<RopeInfo>()
        b.push_str(s: s)
        return b.build()
    }

    static func from_str(_ s: String) -> Rope {
        var b = TreeBuilder<RopeInfo>()
        b.push_str(s: s[...])
        return b.build()
    }

    func iter_chunks<T: IntervalBounds>(range: T) -> ChunkIter {
        let interval = range.into_interval(upper_bound: self.body.len)

        return ChunkIter(cursor: Cursor(n: self, position: interval.start), end: interval.end)
    }

    func slice_to_cow<T: IntervalBounds>(range: T) -> String {
        var iter = self.iter_chunks(range: range)
        let first = iter.next()
        let second = iter.next()
        if first == nil && second == nil {
            return ""
        }
        if second == nil {
            return first!
        }
        if first == nil {
            fatalError("should never happen")
        }
        let one = first!
        let two = second!

        var result = one + two
        for chunk in iter {
            result.append(chunk)
        }
        return result
    }

    func to_string() -> String {
        return slice_to_cow(range: RangeFull())
    }
}

struct ChunkIter: IteratorProtocol, Sequence {
    typealias Element = String

    var cursor: Cursor<RopeInfo>
    let end: UInt

    init(cursor: Cursor<RopeInfo>, end: UInt) {
        self.cursor = cursor
        self.end = end
    }

    mutating func next() -> String? {
        if self.cursor.pos() >= self.end {
            return .none
        }
        let (leaf, start_pos) = self.cursor.get_leaf()!
        let len = Swift.min(self.end - self.cursor.pos(), leaf.len() - start_pos)
        self.cursor.next_leaf()
        return .some(String(leaf.uintO(start_pos, start_pos + len)))
    }
    
}

typealias RopeDelta = Delta<RopeInfo>


// line iterators
struct LinesRaw: IteratorProtocol, Sequence {
    var inner: ChunkIter
    var fragment: Substring

    // FIXME: how are copies handled here?
    mutating func next() -> String? {
        var result:String = ""
        while true {
            if self.fragment.isEmpty {
                let nxt = self.inner.next()
                if nxt == nil {
                    return result.isEmpty ? .none : .some(result)
                }
                let chunk = nxt!
                self.fragment = chunk[...]
                if self.fragment.isEmpty {
                    // can only happen on empty input
                    return .none
                }
            }

            switch self.fragment.memchr("\n") {
            case let .some(i):
                result.append(String(self.fragment.uintC(0, i)))
                self.fragment = self.fragment.uintO(i + 1, UInt(self.fragment.count))
                return .some(result);
            case .none:
                result.append(String(self.fragment))
                self.fragment = ""
            }
        }
    }
}

struct Lines: IteratorProtocol, Sequence {
    var inner: LinesRaw

    mutating func next() -> String? {
        switch self.inner.next() {
        case .some(var s):
            if s.hasSuffix("\n") {
                s = String(s.prefix(s.count - 1))
                if s.hasSuffix("\r") {
                    s = String(s.prefix(s.count - 1))
                }
            }
            return .some(s)
        case .none:
            return .none
        }
    }

    static func def() -> Lines {
        let rope = Rope.from_str("")
        let cursor = Cursor.init(n: rope, position: 0)
        let chunkiter = ChunkIter(cursor: cursor, end: 0)
        let inner = LinesRaw(inner: chunkiter, fragment: "")
        return Lines(inner: inner)
    }
}
