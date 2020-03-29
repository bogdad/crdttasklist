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

struct Segment: Codable, Equatable {
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

struct Mapper {
    var range_iter: RangeIter
    // Not actually necessary for computation, just for dynamic checking of invariant
    var last_i: UInt
    var cur_range: (UInt, UInt)
    var subset_amount_consumed: UInt
    init(_ range_iter: RangeIter) {
        self.range_iter = range_iter
        self.last_i = 0
        self.cur_range = (0, 0)
        self.subset_amount_consumed = 0
    }

    /// Map a coordinate in the document this subset corresponds to, to a
    /// coordinate in the subset matched by the `CountMatcher`. For example,
    /// if the Subset is a set of deletions and the matcher is
    /// `CountMatcher::NonZero`, this would map indices in the union string to
    /// indices in the tombstones string.
    ///
    /// Will return the closest coordinate in the subset if the index is not
    /// in the subset. If the coordinate is past the end of the subset it will
    /// return one more than the largest index in the subset (i.e the length).
    /// This behaviour is suitable for mapping closed-open intervals in a
    /// string to intervals in a subset of the string.
    ///
    /// In order to guarantee good performance, this method must be called
    /// with `i` values in non-decreasing order or it will panic. This allows
    /// the total cost to be O(n) where `n = max(calls,ranges)` over all times
    /// called on a single `Mapper`.
    mutating func doc_index_to_subset(_ i: UInt) -> UInt {
        assert(i >= self.last_i, "method must be called with i in non-decreasing order.")
        self.last_i = i

        while i >= self.cur_range.1 {
            self.subset_amount_consumed += self.cur_range.1 - self.cur_range.0
            let next = self.range_iter.next()
            if next == nil {
                self.cur_range = (UInt.max, UInt.max)
                return self.subset_amount_consumed
            }
            self.cur_range = next!
        }

        if i >= self.cur_range.0 {
            let dist_in_range = i - self.cur_range.0
            return dist_in_range + self.subset_amount_consumed
        } else {
            // not in the subset
            return self.subset_amount_consumed
        }
    }
}

/// See `Subset::zip`
struct ZipIter: IteratorProtocol, Sequence {
    typealias Element = ZipSegment

    var a_segs: [Segment]
    var b_segs: [Segment]
    var a_i: UInt
    var b_i: UInt
    var a_consumed: UInt
    var b_consumed: UInt
    var consumed: UInt

    init(a_segs: [Segment], b_segs: [Segment]) {
        self.a_segs = a_segs
        self.b_segs = b_segs
        self.a_i = 0
        self.b_i = 0
        self.a_consumed = 0
        self.b_consumed = 0
        self.consumed = 0
    }

    /// Consume as far as possible from `self.consumed` until reaching a
    /// segment boundary in either `Subset`, and return the resulting
    /// `ZipSegment`. Will panic if it reaches the end of one `Subset` before
    /// the other, that is when they have different total length.
    mutating func next() -> ZipSegment? {
        let aa = self.a_segs[safe: Int(self.a_i)]
        let bb = self.b_segs[safe: Int(self.b_i)]
        if aa == nil && bb == nil {
            return .none
        }
        if (aa != nil && bb == nil) || (aa == nil && bb != nil) {
            fatalError("can't zip Subsets of different base lengths.")
        }
        let a_len = aa!.len
        let b_len = bb!.len
        let a_count = aa!.count
        let b_count = bb!.count

        var len: UInt = 0
        if a_len + self.a_consumed == b_len + self.b_consumed {
            self.a_consumed += a_len
            self.a_i += 1
            self.b_consumed += b_len
            self.b_i += 1
            len = self.a_consumed - self.consumed
        } else if a_len + self.a_consumed < b_len + self.b_consumed {
            self.a_consumed += a_len
            self.a_i += 1
            len = self.a_consumed - self.consumed
        } else {
            self.b_consumed += b_len
            self.b_i += 1
            len = self.b_consumed - self.consumed
        }
        self.consumed += len
        return .some(ZipSegment(len, a_count, b_count))
    }
}



/// See `Subset::zip`
struct ZipSegment {
    var len: UInt
    var a_count: UInt
    var b_count: UInt
    init(_ len: UInt, _ a_count: UInt, _ b_count: UInt) {
        self.len = len
        self.a_count = a_count
        self.b_count = b_count
    }
}


struct Subset: Codable, Equatable {
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

    func len() -> UInt { return self.count(.All)}

    func dbg() -> String {
        var res = ""
        for s in self.segments {
            var chr: Character
            if s.count == 0 {
                chr = "-"
            } else if s.count == 1 {
                chr = "#"
            } else if s.count <= 9 {
                chr = "\(s.count)".first!
            } else {
                chr = "+"
            }
            res += String(repeating: chr, count: Int(s.len))
        }
        return res
    }

    func delete_from_string(_ s: inout String) -> String {
        var result = String()
            for (b, e) in self.range_iter(CountMatcher.Zero) {
                result.append(contentsOf: s.uintO(b, e))
        }
        return result
    }

    func delete_from_string(_ s: String) -> String {
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
            self.segments
                .filter { matcher.matches(seg: $0)}
                .map {$0.len}
                .reduce(0, +)
    }


    /// Find the complement of this Subset. Every 0-count element will have a
    /// count of 1 and every non-zero element will have a count of 0.
    func complement() -> Subset {
        var sb = SubsetBuilder()
        for seg in self.segments {
            if seg.count == 0 {
                sb.push_segment(seg.len, 1)
            } else {
                sb.push_segment(seg.len, 0)
            }
        }
        return sb.build()
    }

    /// Convenience alias for `self.range_iter(CountMatcher::Zero)`.
    /// Semantically iterates the ranges of the complement of this `Subset`.
    func complement_iter() -> RangeIter {
        return self.range_iter(CountMatcher.Zero)
    }

    /// Compute the difference of two subsets. The count of an element in the
    /// result is the subtraction of the counts of other from self.
    func subtract(_ other: inout Subset) -> Subset {
        var sb = SubsetBuilder()
        for zseg in self.zip(&other) {
            assert(
                zseg.a_count >= zseg.b_count,
                "can't subtract from")
            sb.push_segment(zseg.len, zseg.a_count - zseg.b_count)
        }
        return sb.build()
    }

    /// Compute the bitwise xor of two subsets, useful as a reversible
    /// difference. The count of an element in the result is the bitwise xor
    /// of the counts of the inputs. Unchanged segments will be 0.
    ///
    /// This works like set symmetric difference when all counts are 0 or 1
    /// but it extends nicely to the case of larger counts.
    func bitxor(_ other: inout Subset) -> Subset {
        var sb = SubsetBuilder()
        for zseg in self.zip(&other) {
            sb.push_segment(zseg.len, zseg.a_count ^ zseg.b_count)
        }
        return sb.build()
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

    /// Transform subset through other coordinate transform, shrinking.
    /// The following equation is satisfied:
    ///
    /// C = A.transform_expand(B)
    ///
    /// B.transform_shrink(C).delete_from_string(C.delete_from_string(s)) =
    ///   A.delete_from_string(B.delete_from_string(s))
    func transform_shrink(_ other: inout Subset) -> Subset {
        var sb = SubsetBuilder()
        // discard ZipSegments where the shrinking set has positive count
        for zseg in self.zip(&other) {
            // TODO: should this actually do something like subtract counts?
            if zseg.b_count == 0 {
                sb.push_segment(zseg.len, zseg.a_count)
            }
        }
        return sb.build()
    }

    // Map the contents of `self` into the 0-regions of `other`.
    /// Precondition: `self.count(CountMatcher::All) == other.count(CountMatcher::Zero)`
    func transform(_ other: Cow<Subset>, _ union: Bool) -> Subset {
        print("\(self.count(.All)) == \(other.value.count(.Zero))")
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

    /// The same as taking transform_expand and then unioning with `other`.
    func transform_union(_ other: Cow<Subset>) -> Subset {
        return self.transform(other, true)
    }

    // Compute the union of two subsets. The count of an element in the
    // result is the sum of the counts in the inputs.
    func union(_ other: inout Subset) -> Subset {
        var sb = SubsetBuilder()
        for zseg in self.zip(&other) {
            sb.push_segment(zseg.len, zseg.a_count + zseg.b_count)
        }
        return sb.build()
    }

    // Return an iterator over `ZipSegment`s where each `ZipSegment` contains
    // the count for both self and other in that range. The two `Subset`s
    // must have the same total length.
    //
    // Each returned `ZipSegment` will differ in at least one count.
    func zip(_ other: inout Subset) -> ZipIter {
        return ZipIter(
            a_segs: self.segments,
            b_segs: other.segments)
    }

    func mapper(_ matcher: CountMatcher) -> Mapper {
        return Mapper(self.range_iter(matcher))
    }

    /// Determine whether the subset is empty.
    /// In this case deleting it would do nothing.
    func is_empty() -> Bool {
        return (self.segments.isEmpty) || ((self.segments.count == 1) && (self.segments[0].count == 0))
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
