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

/// Describes what has changed after a batch of word wrapping; this is used
/// for minimal invalidation.
struct InvalLines {
  let start_line: UInt
  let inval_count: UInt
  let new_count: UInt
}

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

extension WrapWidth: Codable {
  enum CodingKeys: String, CodingKey {
    case type
    case bytes
    case width
  }
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: WrapWidth.CodingKeys.self)
    let type = try container.decode(Int.self, forKey: .type)
    let bytes = try container.decodeIfPresent(UInt.self, forKey: .bytes)
    let width = try container.decodeIfPresent(Double.self, forKey: .width)
    switch type {
    case 0:
      self = .None
    case 1:
      self = .Bytes(bytes!)
    case 2:
      self = .Width(width!)
    default:
      fatalError("should not happen")
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: WrapWidth.CodingKeys.self)
    switch self {
    case .None:
      try container.encode(0, forKey: .type)
    case .Bytes(let bytes):
      try container.encode(1, forKey: .type)
      try container.encode(bytes, forKey: .bytes)
    case .Width(let width):
      try container.encode(2, forKey: .type)
      try container.encode(width, forKey: .width)
    }
  }
}

struct LinesW: Codable, Equatable {
  var wrap: WrapWidth
  var breaks: Breaks

  func visual_line_of_offset(_ text: Rope, _ offset: UInt) -> UInt {
    var line = text.line_of_offset(offset)
    if self.wrap != WrapWidth.None {
      line += NodeMeasurable<BreaksInfo, BreaksMetric>.count(self.breaks, offset)
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
      var cursor = MergedBreaks(text, self.breaks)
      return cursor.offset_of_line(line)
    }
  }

  static func def() -> LinesW {
    return LinesW(wrap: WrapWidth.None, breaks: Breaks.def())
  }

  /// Updates breaks after an edit. Returns `InvalLines`, for minimal invalidation,
  /// when possible.
  mutating func after_edit(
    text: Rope,
    old_text: Rope,
    delta: RopeDelta,
    //width_cache: &mut WidthCache,
    //client: &Client,
    visible_lines: Range<UInt>
  ) -> InvalLines? {
    let (iv, newlen) = delta.summary()

    let logical_start_line = text.line_of_offset(iv.start)
    let old_logical_end_line = old_text.line_of_offset(iv.end) + 1
    let new_logical_end_line = text.line_of_offset(iv.start + newlen) + 1
    let old_logical_end_offset = old_text.offset_of_line(old_logical_end_line)
    let old_hard_count = old_logical_end_line - logical_start_line
    let new_hard_count = new_logical_end_line - logical_start_line

    //TODO: we should be able to avoid wrapping the whole para in most cases,
    // but the logic is trickier.
    let prev_break = text.offset_of_line(logical_start_line)
    let _next_hard_break = text.offset_of_line(new_logical_end_line)

    // count the soft breaks in the region we will rewrap, before we update them.

    let _inval_soft =
      NodeMeasurable<BreaksInfo, BreaksMetric>.count(self.breaks, old_logical_end_offset)
      - NodeMeasurable<BreaksInfo, BreaksMetric>.count(self.breaks, prev_break)

    // update soft breaks, adding empty spans in the edited region
    var builder = BreakBuilder()
    builder.add_no_break(newlen)
    self.breaks = self.breaks.edit(iv, builder.build())
    // XXXXXXXXXXXXXXX self.patchup_tasks(iv, newlen)

    if self.wrap == .None {
      return InvalLines(
        start_line: logical_start_line,
        inval_count: old_hard_count,
        new_count: new_hard_count
      )
    }
    // XXXXXXXXXXXXXXXXX ?????????????
    /*let new_task = prev_break..next_hard_break;
        self.add_task(new_task);

        // possible if the whole buffer is deleted, e.g
        if !self.work.is_empty() {
            let summary = self.do_wrap_task(text, width_cache, client, visible_lines, None);
            let WrapSummary { start_line, new_soft, .. } = summary;
            // if we haven't converged after this update we can't do minimal invalidation
            // because we don't have complete knowledge of the new breaks state.
            if self.is_converged() {
                let inval_count = old_hard_count + inval_soft;
                let new_count = new_hard_count + new_soft;
                Some(InvalLines { start_line, new_count, inval_count })
            } else {
                None
            }
        } else {
            None
        }*/
    return nil
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
  let MAX_LINEAR_DIST: UInt = 20
  var text: Cursor<RopeInfo>
  var soft: Cursor<BreaksInfo>
  var offset: UInt
  /// Starting from zero, how many calls to `next` to get to `self.offset`?
  var cur_line: UInt
  let total_lines: UInt
  /// Total length, in base units
  let len: UInt

  func at_eof() -> Bool { return self.offset == self.len }

  mutating func eof_without_newline() -> Bool {
    assert(self.at_eof())
    self.text.set(self.len)
    return self.text.get_leaf()
      .map({ (l, _) in l.last != "\n" })!
  }

  init(_ text: Rope, _ soft: Breaks) {
    self.text = Cursor(text)
    self.soft = Cursor(soft)
    self.total_lines =
      NodeMeasurable<RopeInfo, LinesMetric>.measure(self.text.root)
      + NodeMeasurable<BreaksInfo, BreaksMetric>.measure(self.soft.root)
      + 1
    self.len = self.text.total_len()
    self.cur_line = 0
    self.offset = 0
  }

  mutating func offset_of_line(_ line: UInt) -> UInt {
    if line == 0 {
      return 0
    }
    if line >= self.total_lines {
      return self.text.total_len()
    }
    if line == self.cur_line {
      return self.offset
    }
    if line > self.cur_line && line - self.cur_line < MAX_LINEAR_DIST {
      return self.offset_of_line_linear(line)
    }
    return self.offset_of_line_bsearch(line)
  }

  mutating func offset_of_line_linear(_ line: UInt) -> UInt {
    assert(line > self.cur_line)
    let dist = line - self.cur_line
    return self.nth(Int(dist - 1)) ?? self.len
  }

  mutating func offset_of_line_bsearch(_ line: UInt) -> UInt {
    var range = 0..<self.len
    while true {
      let pivot = range.startIndex + (range.upperBound - range.startIndex) / 2
      self.set_offset(pivot)
      let l = self.cur_line
      if l == line {
        return self.offset
      }
      if l > line {
        range = range.startIndex..<pivot + 1
      } else if line - l < MAX_LINEAR_DIST {
        range = pivot..<range.upperBound
      } else {
        return self.offset_of_line_linear(line)
      }
    }
  }

  /// Sets the `self.offset` to the first valid break immediately at or preceding `offset`,
  /// and restores invariants.
  mutating func set_offset(_ offset: UInt) {
    self.text.set(offset)
    self.soft.set(offset)
    if offset > 0 {
      if CursorMeasurable<RopeInfo, LinesMetric>.at_or_prev(&text) == nil {
        self.text.set(0)
      }

      if CursorMeasurable<BreaksInfo, BreaksMetric>.at_or_prev(&soft) == nil {
        self.soft.set(0)
      }
    }

    // self.offset should be at the first valid break immediately preceding `offset`, or 0.
    // the position of the non-break cursor should be > than that of the break cursor, or EOF.
    let less = self.text.pos() < self.soft.pos()
    let eq = self.text.pos() == self.soft.pos()
    if less {
      let _ = CursorMeasurable<RopeInfo, LinesMetric>.next(&self.text)
    } else if eq {
      assert(self.text.pos() == 0)
    } else /* greater */
    {
      let _ = CursorMeasurable<BreaksInfo, BreaksMetric>.next(&self.soft)
    }

    self.offset = Swift.min(self.text.pos(), self.soft.pos())
    self.cur_line = merged_line_of_offset(self.text.root, self.soft.root, self.offset)
  }

  func merged_line_of_offset(_ text: Rope, _ soft: Breaks, _ offset: UInt) -> UInt {
    return NodeMeasurable<RopeInfo, LinesMetric>.count(text, offset)
      + NodeMeasurable<BreaksInfo, BreaksMetric>.count(soft, offset)
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
      return nil
    } else {
      self.cur_line += 1
      return self.offset
    }
  }

}
