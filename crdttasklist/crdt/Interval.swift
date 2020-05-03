//
//  Interval.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 5/25/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
//  Its actually a direct translation of Rope from
//  https://github.com/xi-editor/xi-editor/blob/master/rust/rope/src/interval.rs
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

protocol IntervalBounds {
    func into_interval(upper_bound:UInt) -> Interval
}

struct RangeFull: IntervalBounds {
    func into_interval(upper_bound: UInt) -> Interval {
        return Interval(0, upper_bound)
    }
}

struct Interval: Equatable, IntervalBounds {
    var start: UInt
    var end: UInt
    init(_ start: UInt, _ end: UInt) {
        assert(start <= end)
        self.start = start
        self.end = end
    }

    init(from: Int, length: Int) {
        self.init(UInt(from), UInt(from + length))
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
    func into_interval(upper_bound: UInt) -> Interval {
        return self.intersect(other: Interval(0, upper_bound))
    }

    // the first half of self - other
    func prefix(_ other: Interval) -> Interval {
        return Interval(min(self.start, other.start), min(self.end, other.start))
    }

    // the second half of self - other
    func suffix(_ other: Interval) -> Interval {
        return Interval(max(self.start, other.end), max(self.end, other.end))
    }

    func len() -> Int {
        return Int(end) - Int(start)
    }
}
