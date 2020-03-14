//
//  LineWrap.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 7/7/19.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//
//  Its actually a direct translation of View from
//  https://github.com/xi-editor/xi-editor/blob/master/rust/core-lib/src/linewrap.rs
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

enum WrapWidth: Equatable {
    /// No wrapping in effect.
    case None

    /// Width in bytes (utf-8 code units).
    ///
    /// Only works well for ASCII, will probably not be maintained long-term.
    case Bytes(UInt)

    /// Width in px units, requiring measurement by the front-end.
    case Width(Double)
}

struct LinesW {
    var wrap: WrapWidth
    var breaks: Breaks

    func visual_line_of_offset(_ text: Rope, _ offset: UInt) -> UInt {
        var line = text.line_of_offset(offset)
        if self.wrap != WrapWidth.None {
            line += NodeMeasurable.count(self.breaks, BreaksMetric.self, offset)
        }
        return line
    }

    /// Returns the byte offset corresponding to the line `line`.
    func offset_of_visual_line(_ text: Rope, _ line: UInt) -> UInt {
        switch self.wrap {
        case .None:
            // sanitize input
            let line2 = min(MetricMeasurable<RopeInfo, LinesMetric>.measure(text) + 1, line)
            return text.offset_of_line(line2)
        default:
                let mut cursor = MergedBreaks::new(text, &self.breaks);
                cursor.offset_of_line(line)
        }
    }

    static func def() -> LinesW {
        return LinesW(wrap: WrapWidth.None, breaks: Breaks.def())
    }

}

/// A cursor over both hard and soft breaks. Hard breaks are retrieved from
/// the rope; the soft breaks are stored independently; this interleaves them.
///
/// # Invariants:
///
/// `self.offset` is always a valid break in one of the cursors, unless
/// at 0 or EOF.
///
/// `self.offset == self.text.pos().min(self.soft.pos())`.
struct MergedBreaks {
    var text: Cursor<RopeInfo>
    var soft: Cursor<BreaksInfo>
    var offset: UInt
    /// Starting from zero, how many calls to `next` to get to `self.offset`?
    var cur_line: UInt
    let total_lines: UInt
    /// Total length, in base units
    let len: UInt

    func at_eof() -> Bool { self.offset == self.len }

    mutating func eof_without_newline() -> Bool {
        assert(self.at_eof())
        self.text.set(self.len)
        return self.text.get_leaf()
            .map({ (l, _) in l.last != "\n"})!
    }
}

extension MergedBreaks: IteratorProtocol, Sequence {
    typealias Element = UInt
    mutating func next() -> UInt? {
        if self.text.pos() == self.offset && !self.at_eof() {
            // don't iterate past EOF, or we can't get the leaf and check for \n
            let _ = CursorMeasurable<RopeInfo, LinesMetric>.next(&self.text)
        }
        if self.soft.pos() == self.offset {
            let _ = CursorMeasurable<BreaksInfo, BreaksMetric>.next(&self.soft)
        }
        let prev_off = self.offset
        self.offset = Swift.min(self.text.pos(), self.soft.pos())

        let eof_without_newline = self.offset > 0 && self.at_eof() && self.eof_without_newline()
        if self.offset == prev_off || eof_without_newline {
            None
        } else {
            self.cur_line += 1;
            Some(self.offset)
        }
    }

}
