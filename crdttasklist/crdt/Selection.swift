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
enum Affinity {
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

struct Selection {
    // An invariant: regions[i].max() <= regions[i+1].min()
    // and < if either is_caret()
    var regions: [SelRegion]

    static func new_simple(_ region: SelRegion) -> Selection {
        return Selection(regions: [region])
    }

    static func from(_ region: SelRegion) -> Selection {
        return new_simple(region)
    }
}

struct SelRegion {
    /// The inactive edge of a selection, as a byte offset. When
    /// equal to end, the selection range acts as a caret.
    let start: UInt

    /// The active edge of a selection, as a byte offset.
    let end: UInt

    /// A saved horizontal position (used primarily for line up/down movement).
    let horiz: HorizPos?

    /// The affinity of the cursor.
    let affinity: Affinity

    func min() -> UInt {
        return Swift.min(self.start, self.end)
    }

    func max() -> UInt {
        return Swift.max(self.start, self.end)
    }

    /// Determines whether the region is a caret (ie has an empty interior).
    func is_caret() -> Bool { self.start == self.end }

    static func caret(_ pos: UInt) -> SelRegion {
        return SelRegion(start: pos, end: pos, horiz: .none, affinity: Affinity.def())
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
