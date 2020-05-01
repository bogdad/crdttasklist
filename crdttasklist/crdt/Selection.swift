//
//  Selection.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 7/7/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
//  Its actually a direct translation of Selection from
//  https://github.com/xi-editor/xi-editor/blob/master/rust/core-lib/src/selection.rs
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

typealias HorizPos = UInt

/// The "affinity" of a cursor which is sitting exactly on a line break.
///
/// We say "cursor" here rather than "caret" because (depending on presentation)
/// the front-end may draw a cursor even when the region is not a caret.
enum Affinity: Int, Codable {
    /// The cursor should be displayed downstream of the line break. For
    /// example, if the buffer is "abcd", and the cursor is on a line break
    /// after "ab", it should be displayed on the second line before "cd".
    case Downstream
    /// The cursor should be displayed upstream of the line break. For
    /// example, if the buffer is "abcd", and the cursor is on a line break
    /// after "ab", it should be displayed on the previous line after "ab".
    case Upstream

    static func def() -> Affinity {
        return .Downstream
    }
}

struct Selection: Codable {
    // An invariant: regions[i].max() <= regions[i+1].min()
    // and < if either is_caret()
    var regions: [SelRegion]

    static func new_simple(_ region: SelRegion) -> Selection {
        return Selection([region])
    }

    static func from(_ region: SelRegion) -> Selection {
        return new_simple(region)
    }

        /// Computes a new selection based on applying a delta to the old selection.
        ///
        /// When new text is inserted at a caret, the new caret can be either before
        /// or after the inserted text, depending on the `after` parameter.
        ///
        /// Whether or not the preceding selections are restored depends on the keep_selections
        /// value (only set to true on transpose).
    func apply_delta(_ delta: RopeDelta, _ after: Bool, _ drift: InsertDrift) -> Selection {
        var result = Selection()
        var transformer = Transformer(delta)
        for region in self.regions {
            let is_caret = region.start == region.end
            let is_region_forward = region.start < region.end
            var start_after = after
            var end_after = after
            if drift == .Inside && !is_caret {
                start_after = !is_region_forward
                end_after = is_region_forward
            } else if drift == .Outside && !is_caret {
                start_after = is_region_forward
                end_after = !is_region_forward
            }

            let new_region = SelRegion(
                transformer.transform(region.start, start_after),
                transformer.transform(region.end, end_after)
            )
            .with_affinity(region.affinity)
            result.add_region(new_region);
        }
        return result
    }

    /// Add a region to the selection. This method implements merging logic.
    ///
    /// Two non-caret regions merge if their interiors intersect; merely
    /// touching at the edges does not cause a merge. A caret merges with
    /// a non-caret if it is in the interior or on either edge. Two carets
    /// merge if they are the same offset.
    ///
    /// Performance note: should be O(1) if the new region strictly comes
    /// after all the others in the selection, otherwise O(n).
    mutating func add_region(_ region: SelRegion) {
        var ix = self.search(region.min())
        if ix == self.regions.count {
            self.regions.append(region)
            return
        }
        var region = region
        var end_ix = ix
        if self.regions[ix].min() <= region.min() {
            if self.regions[ix].should_merge(region) {
                region = self.regions[ix].merge_with(region);
            } else {
                ix += 1
            }
            end_ix += 1
        }
        while end_ix < self.regions.count && region.should_merge(self.regions[end_ix]) {
            region = region.merge_with(self.regions[end_ix]);
            end_ix += 1
        }
        if ix == end_ix {
            self.regions.insert(region, at: ix)
        } else {
            self.regions[ix] = region
            remove_n_at(&self.regions, UInt(ix + 1), UInt(end_ix - ix - 1))
        }
    }


    // The smallest index so that offset > region.max() for all preceding
    // regions.
    func search(_ offset: UInt) -> Int {
        if self.regions.isEmpty || offset > self.regions.last!.max() {
            return self.regions.count
        }
        let (i, _) = self.regions.binary_search_by{ return Int($0.max()) - Int(offset) }
        return i
    }

    init() {
        self.init([])
    }

    init(_ regions: [SelRegion]) {
        self.regions = regions
    }
}

struct SelRegion: Codable {
    /// The inactive edge of a selection, as a byte offset. When
    /// equal to end, the selection range acts as a caret.
    let start: UInt

    /// The active edge of a selection, as a byte offset.
    let end: UInt

    /// A saved horizontal position (used primarily for line up/down movement).
    let horiz: HorizPos?

    /// The affinity of the cursor.
    var affinity: Affinity

    func min() -> UInt {
        return Swift.min(self.start, self.end)
    }

    func max() -> UInt {
        return Swift.max(self.start, self.end)
    }

    /// Determines whether the region is a caret (ie has an empty interior).
    func is_caret() -> Bool { return self.start == self.end }

    static func caret(_ pos: UInt) -> SelRegion {
        return SelRegion(pos, pos)
    }

    static func from(_ interval: Interval) -> SelRegion {
        return SelRegion(interval.start, interval.end)
    }

    init(_ start: UInt, _ end: UInt) {
        self.start = start
        self.end = end
        self.horiz = .none
        self.affinity = .def()
    }

    func with_affinity(_ affinity: Affinity) -> SelRegion {
        var res = self
        res.affinity = affinity
        return res
    }

    // Indicate whether this region should merge with the next.
    // Assumption: regions are sorted (self.min() <= other.min())
    func should_merge(_ other: SelRegion) -> Bool {
        return other.min() < self.max()
            || ((self.is_caret() || other.is_caret()) && other.min() == self.max())
    }

    func merge_with(_ other: SelRegion) -> SelRegion {
        let is_forward = self.end > self.start || other.end > other.start
        let new_min = Swift.min(self.min(), other.min())
        let new_max = Swift.max(self.max(), other.max())
        var start = new_max
        var end = new_min
        if is_forward {
            start = new_min
            end = new_max
        }
        // Could try to preserve horiz/affinity from one of the
        // sources, but very likely not worth it.
        return SelRegion(start, end)
    }

    func to_interval() -> Interval {
        return Interval(start, end)
    }
}

enum InsertDrift {
    /// Indicates to do whatever the `after` bool says to do
    case Default
    /// Indicates this edit should happen within any (non-caret) selections if possible.
    case Inside
    /// Indicates this edit should happen outside any selections if possible.
    case Outside
}
