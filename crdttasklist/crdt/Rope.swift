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
  static let CURSOR_CACHE_SIZE = 4
}

struct RopeConstants {
  static let MIN_LEAF: UInt = 511
  static let MAX_LEAF: UInt = 1024
}

protocol Leaf: Codable, Hashable {
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
  static func measure(_ info: inout N, _ len: UInt) -> UInt
  static func to_base_units(_ l: inout N.L, _ in_measured_units: UInt) -> UInt
  static func from_base_units(_ l: inout N.L, _ in_base_units: UInt) -> UInt
  static func is_boundary(_ l: inout N.L, _ offset: UInt) -> Bool
  static func prev(_ l: inout N.L, _ offset: UInt) -> UInt?
  static func next(_ l: inout N.L, _ offset: UInt) -> UInt?
  static func can_fragment() -> Bool
}

struct RopeInfo: NodeInfo {
  typealias DefaultMetric = BaseMetric

  typealias L = String

  var lines: UInt
  var utf16_size: UInt

  mutating func accumulate(other: inout RopeInfo) {
    self.lines += other.lines
    self.utf16_size += other.utf16_size
  }

  static func compute_info(leaf s: inout String) -> RopeInfo {
    return RopeInfo(
      lines: s.count_newlines(),
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
  static func measure(_ info: inout RopeInfo, _ len: UInt) -> UInt {
    return info.lines
  }

  static func to_base_units(_ l: inout String, _ in_measured_units: UInt) -> UInt {
    var offset: UInt = 0
    for _ in 0..<in_measured_units {
      let substr = l.substr_starting(offset)
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

  static func from_base_units(_ l: inout String, _ in_base_units: UInt) -> UInt {
    return l.uintO(0, in_base_units).count_newlines()
  }

  static func is_boundary(_ l: inout String, _ offset: UInt) -> Bool {
    if offset == 0 {
      // shouldn't be called with this, but be defensive
      return false
    } else {
      return l.at(offset - 1) == "\n"
    }
  }

  static func prev(_ l: inout String, _ offset: UInt) -> UInt? {
    assert(offset > 0, "caller is responsible for validating input")
    let substr = l.uintC(0, offset)
    return substr.firstIndex(of: "\n").map({ (pos: Substring.Index) -> UInt in
      return UInt(pos.utf16Offset(in: substr) + 1)
    })
  }

  static func next(_ l: inout String, _ offset: UInt) -> UInt? {
    let substr = l[String.Index(utf16Offset: Int(offset), in: l)...]
    return substr.firstIndex(of: "\n").map({ (pos: Substring.Index) -> UInt in
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

typealias Rope = Node<RopeInfo>

extension Rope {

  func equals_to_str(_ str: String) -> Bool {
    if str.len() != len() {
      return false
    }
    for i in 0..<len() {
      if byte_at(i) != str.byte_at(i) {
        return false
      }
    }
    return true
  }

  // callers should be encouraged to use cursor instead
  func byte_at(_ offset: UInt) -> UInt8 {
    let cursor = Cursor(self, offset)
    let (leaf, pos) = cursor.get_leaf()!
    return leaf.byte_at(UInt(pos))
  }

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

    return ChunkIter(cursor: Cursor(self, interval.start), end: interval.end)
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

  /// Return the line number corresponding to the byte index `offset`.
  ///
  /// The line number is 0-based, thus this is equivalent to the count of newlines
  /// in the slice up to `offset`.
  ///
  /// Time complexity: O(log n)
  ///
  /// # Panics
  ///
  /// This function will panic if `offset > self.len()`. Callers are expected to
  /// validate their input.
  func line_of_offset(_ offset: UInt) -> UInt {
    return NodeMeasurable2<RopeInfo.DefaultMetric, LinesMetric, RopeInfo>.convert_metrics(
      self, offset)
  }

  /// Return the byte offset corresponding to the line number `line`.
  /// If `line` is equal to one plus the current number of lines,
  /// this returns the offset of the end of the rope. Arguments higher
  /// than this will panic.
  ///
  /// The line number is 0-based.
  ///
  /// Time complexity: O(log n)
  ///
  /// # Panics
  ///
  /// This function will panic if `line > self.measure::<LinesMetric>() + 1`.
  /// Callers are expected to validate their input.
  func offset_of_line(_ line: UInt) -> UInt {
    let max_line = MetricMeasurable<RopeInfo, LinesMetric>.measure(self) + 1
    if line > max_line {
      fatalError("line number \(line) beyond last line \(max_line)")
    } else if line == max_line {
      return self.len()
    }
    return NodeMeasurable<RopeInfo, LinesMetric>.count_base_units(self, line)
  }

  /// Return the offset of the codepoint before `offset`.
  func prev_codepoint_offset(_ offset: UInt) -> UInt? {
    var cursor = Cursor(self, offset)
    return CursorMeasurable<RopeInfo, BaseMetric>.prev(&cursor)
  }

  // Returns a new Rope with the contents of the provided range.
  func slice<T: IntervalBounds>(_ iv: T) -> Rope {
    return self.subseq(iv)
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
    let len = Swift.min(self.end - self.cursor.pos(), leaf.len() - UInt(start_pos))
    let _ = self.cursor.next_leaf()
    return .some(String(leaf.uintO(UInt(start_pos), UInt(start_pos) + len)))
  }

}

typealias RopeDelta = Delta<RopeInfo>

// line iterators
struct LinesRaw: IteratorProtocol, Sequence {
  var inner: ChunkIter
  var fragment: Substring

  // FIXME: how are copies handled here?
  mutating func next() -> String? {
    var result: String = ""
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
        return .some(result)
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
    let cursor = Cursor.init(rope, 0)
    let chunkiter = ChunkIter(cursor: cursor, end: 0)
    let inner = LinesRaw(inner: chunkiter, fragment: "")
    return Lines(inner: inner)
  }
}

//TODO: document metrics, based on https://github.com/google/xi-editor/issues/456
//See ../docs/MetricsAndBoundaries.md for more information.
/// This metric let us walk utf8 text by code point.
///
/// `BaseMetric` implements the trait [Metric].  Both its _measured unit_ and
/// its _base unit_ are utf8 code unit.
///
/// Offsets that do not correspond to codepoint boundaries are _invalid_, and
/// calling functions that assume valid offsets with invalid offets will panic
/// in debug mode.
///
/// Boundary is atomic and determined by codepoint boundary.  Atomicity is
/// implicit, because offsets between two utf8 code units that form a code
/// point is considered invalid. For example, if a string starts with a
/// 0xC2 byte, then `offset=1` is invalid.
struct BaseMetric: Metric {
  typealias N = RopeInfo

  static func measure(_ info: inout RopeInfo, _ len: UInt) -> UInt {
    return len
  }

  static func to_base_units(_ l: inout String, _ in_measured_units: UInt) -> UInt {
    assert(l.is_char_boundary(in_measured_units))
    return in_measured_units
  }

  static func from_base_units(_ l: inout String, _ in_base_units: UInt) -> UInt {
    assert(l.is_char_boundary(in_base_units))
    return in_base_units
  }

  static func is_boundary(_ l: inout String, _ offset: UInt) -> Bool {
    return l.is_char_boundary(offset)
  }

  static func prev(_ l: inout String, _ offset: UInt) -> UInt? {
    if offset == 0 {
      // I think it's a precondition that this will never be called
      // with offset == 0, but be defensive.
      return nil
    } else {
      var len: UInt = 1
      while !l.is_char_boundary(offset - len) {
        len += 1
      }
      return offset - len
    }
  }

  static func next(_ l: inout String, _ offset: UInt) -> UInt? {
    if offset == l.len() {
      // I think it's a precondition that this will never be called
      // with offset == s.len(), but be defensive.
      return nil
    } else {
      let b = l.uintO(offset, offset)  //l.as_bytes()[offset]
      return offset + Utils.len_utf8_from_first_byte(b)
    }
  }

  static func can_fragment() -> Bool {
    return false
  }
}

extension Cursor where N == RopeInfo {
  mutating func prev_codepoint() -> Character? {
    let _ = CursorMeasurable<RopeInfo, BaseMetric>.prev(&self)
    if let (l, offset) = self.get_leaf() {
      //return
      let ss: Substring = l.uintO(UInt(offset), l.len())
      // TODO: performance
      return Array(ss).first
    } else {
      return nil
    }
  }
}
