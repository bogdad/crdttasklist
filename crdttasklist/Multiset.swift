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
