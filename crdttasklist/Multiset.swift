//
//  Multiset.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 5/25/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
//  Its actually a direct translation of Delta from
//  https://github.com/xi-editor/xi-editor/blob/master/rust/rope/src/multiset.rs
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

struct Segment {
    var len: UInt
    var count: UInt
    init(_ len: UInt, _ count: UInt) {
        self.len = len
        self.count = count
    }
    func clone() -> Segment {
        return Segment(len, count)
    }
}

/// Determines which elements of a `Subset` a method applies to
/// based on the count of the element.
enum CountMatcher {
    case Zero
    case NonZero
    case All

    func matches(seg: inout Segment) -> Bool {
        switch self {
        case .Zero:
           return (seg.count == 0)
        case .NonZero:
           return (seg.count != 0)
        case .All:
            return true
        }
    }

    func matches(seg: Segment) -> Bool {
        switch self {
        case .Zero:
            return (seg.count == 0)
        case .NonZero:
            return (seg.count != 0)
        case .All:
            return true
        }
    }
}



struct Subset {
    /// Invariant, maintained by `SubsetBuilder`: all `Segment`s have non-zero
    /// length, and no `Segment` has the same count as the one before it.
    let segments: [Segment]

    init(_ segments: [Segment]) {
        self.segments = segments
    }

    static func make_empty(_ len: UInt) -> Subset {
        var sb = SubsetBuilder()
        sb.pad_to_len(len)
        return sb.build()
    }

    func delete_from_string(_ s: inout String) -> String {
        var result = String()
            for (b, e) in self.range_iter(CountMatcher.Zero) {
                result.append(contentsOf: s.uintO(b, e))
        }
        return result
    }

    /// Return an iterator over the ranges with a count matching the `matcher`.
    /// These will often be easier to work with than raw segments.
    func range_iter(_ matcher: CountMatcher) -> RangeIter {
        return RangeIter(self.segments.makeIterator(), matcher)
    }

    /// The length of the resulting sequence after deleting this subset. A
    /// convenience alias for `self.count(CountMatcher::Zero)` to reduce
    /// thinking about what that means in the cases where the length after
    /// delete is what you want to know.
    ///
    /// `self.delete_from_string(s).len() = self.len(s.len())`
    func len_after_delete() -> UInt {
        return self.count(CountMatcher.Zero)
    }

    /// Count the total length of all the segments matching `matcher`.
    func count(_ matcher: CountMatcher) -> UInt {
        return
            self.segments.makeIterator()
                .filter { matcher.matches(seg: $0)}
                .map {$0.count}
                .reduce(0, +)
    }


    /// Convenience alias for `self.range_iter(CountMatcher::Zero)`.
    /// Semantically iterates the ranges of the complement of this `Subset`.
    func complement_iter() -> RangeIter {
        return self.range_iter(CountMatcher.Zero)
    }

    /// Transform through coordinate transform represented by other.
    /// The equation satisfied is as follows:
    ///
    /// s1 = other.delete_from_string(s0)
    ///
    /// s2 = self.delete_from_string(s1)
    ///
    /// element in self.transform_expand(other).delete_from_string(s0) if (not in s1) or in s2
    func transform_expand(_ other: Cow<Subset>) -> Subset {
        return self.transform(other, false)
    }

    // Map the contents of `self` into the 0-regions of `other`.
    /// Precondition: `self.count(CountMatcher::All) == other.count(CountMatcher::Zero)`
    func transform(other: Cow<Subset>, union: Bool) -> Subset {
        var sb = SubsetBuilder()
        var seg_iter = self.segments.makeIterator()
        var cur_seg = Segment(0, 0)
        for oseg in other.value.segments {
            if oseg.count > 0 {
                sb.push_segment(oseg.len, union ? oseg.count : 0)
            } else {
                // fill 0-region with segments from self.
                var to_be_consumed = oseg.len;
                while to_be_consumed > 0 {
                    if cur_seg.len == 0 {
                        let seg_iter_next = seg_iter.next()
                        if seg_iter_next == nil {
                            fatalError("self must cover all 0-regions of other")
                        }
                        cur_seg = seg_iter_next!.clone()
                    }
                    // consume as much of the segment as possible and necessary
                    let to_consume = min(cur_seg.len, to_be_consumed)
                    sb.push_segment(to_consume, cur_seg.count)
                    to_be_consumed -= to_consume
                    cur_seg.len -= to_consume
                }
            }
        }
        assert(cur_seg.len == 0, "the 0-regions of other must be the size of self")
        assert(seg_iter.next() == nil, "the 0-regions of other must be the size of self")
        return sb.build()
    }

    func clone() -> Subset {
        return Subset(self.segments)
    }
}

struct SubsetBuilder {
    var segments: [Segment]
    var total_len: UInt

    init() {
        self.segments = []
        self.total_len = 0
    }

    mutating func push_segment(_ len: UInt, _ count: UInt) {
        assert(len > 0, "can't push empty segment");
        self.total_len += len

        // merge if possible
        if segments.last != nil {
            if segments[segments.count - 1].count == count {
                segments[segments.count - 1].len += len
                return
            }
        }
        self.segments.append(Segment(len, count))
    }

    /// Sets the count for a given range. This method must be called with a
    /// non-empty range with `begin` not before the largest range or segment added
    /// so far. Gaps will be filled with a 0-count segment.
    mutating func add_range(_ begin: UInt, _ end: UInt, _ count: UInt) {
        assert(begin >= self.total_len, "ranges must be added in non-decreasing order")
        // assert!(begin < end, "ranges added must be non-empty: [{},{})", begin, end);
        if begin >= end {
            return
        }
        let len = end - begin
        let cur_total_len = self.total_len

        // add 0-count segment to fill any gap
        if begin > self.total_len {
            self.push_segment(begin - cur_total_len, 0)
        }

        self.push_segment(len, count)
    }


    mutating func pad_to_len(_ total_len: UInt) {
        if total_len > self.total_len {
            let cur_len = self.total_len
            self.push_segment(total_len - cur_len, 0)
        }
    }

    func build() -> Subset {
        return Subset(self.segments)
    }
}

struct RangeIter: IteratorProtocol, Sequence {
    typealias Element = (UInt, UInt)

    var it: Array<Segment>.Iterator
    var consumed: UInt
    let matcher: CountMatcher

    init(_ it: Array<Segment>.Iterator, _ matcher: CountMatcher) {
        self.it = it
        self.consumed = 0
        self.matcher = matcher
    }

    mutating func next() -> (UInt, UInt)? {
        while true {
            var nx = it.next()
            if nx == nil {
                return .none
            }
            self.consumed += nx!.len
            if self.matcher.matches(seg: &nx!) {
                return (self.consumed - nx!.len, self.consumed)
            }
        }
    }
}
