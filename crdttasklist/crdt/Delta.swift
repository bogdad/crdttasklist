//
//  Delta.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 5/25/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
//  Its actually a direct translation of Delta from
//  https://github.com/xi-editor/xi-editor/blob/master/rust/rope/src/delta.rs
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

enum DeltaElement<N: NodeInfo> {
  /// Represents a range of text in the base document. Includes beginning, excludes end.
  case Copy(UInt, UInt)  // note: for now, we lose open/closed info at interval endpoints
  case Insert(Node<N>)
}

class Delta<N: NodeInfo> {
  var els: [DeltaElement<N>]
  var base_len: UInt

  init(_ els: [DeltaElement<N>], _ base_len: UInt) {
    self.els = els
    self.base_len = base_len
  }

  static func simple_edit<T: IntervalBounds>(_ interval: T, _ rope: Node<N>, _ base_len: UInt)
    -> Delta<N>
  {
    var builder = DeltaBuilder<N>(base_len)
    if rope.is_empty() {
      builder.delete(interval)
    } else {
      builder.replace(interval, rope)
    }
    return builder.build()
  }

  /// Apply the delta to the given rope. May not work well if the length of the rope
  /// is not compatible with the construction of the delta.
  func apply(_ base: Node<N>) -> Node<N> {
    assert(base.len() == self.base_len, "must apply Delta to Node of correct length")
    var b = TreeBuilder<N>()
    for elem in self.els {
      switch elem {
      case .Copy(let tpl):
        base.push_subseq(b: &b, iv: Interval(tpl.0, tpl.1))
      case .Insert(let n):
        b.push(n: n.clone())
      }
    }
    return b.build()
  }

  // Returns the length of the new document. In other words, the length of
  // the transformed string after this Delta is applied.
  //
  // `d.apply(r).len() == d.new_document_len()`
  func new_document_len() -> UInt {
    return Delta.total_element_len(self.els[...])
  }

  static func total_element_len(_ els: ArraySlice<DeltaElement<N>>) -> UInt {
    return els.reduce(
      UInt(0),
      { (sum, el) in

        var add: UInt = 0
        switch el {
        case .Copy(let beg, let end):
          add = end - beg
        case .Insert(let n):
          add = n.len()
        }
        return sum + add
      })
  }

  // FIXME: what does it do?
  func factor() -> (InsertDelta<N>, Subset) {
    var ins = [DeltaElement<N>]()
    var sb = SubsetBuilder()
    var b1: UInt = 0
    var e1: UInt = 0
    for elem in self.els {
      switch elem {
      case DeltaElement.Copy(let b, let e):
        sb.add_range(e1, b, 1)
        e1 = e
      case DeltaElement.Insert(let n):
        if e1 > b1 {
          ins.append(DeltaElement.Copy(b1, e1))
        }
        b1 = e1
        ins.append(DeltaElement.Insert(n))
      }
    }
    if b1 < self.base_len {
      ins.append(DeltaElement.Copy(b1, self.base_len))
    }
    sb.add_range(e1, self.base_len, 1)
    sb.pad_to_len(self.base_len)
    return (InsertDelta(elem: Delta(ins, self.base_len)), sb.build())
  }

  // Synthesize a delta from a "union string" and two subsets: an old set
  // of deletions and a new set of deletions from the union. The Delta is
  // from text to text, not union to union; anything in both subsets will
  // be assumed to be missing from the Delta base and the new text. You can
  // also think of these as a set of insertions and one of deletions, with
  // overlap doing nothing. This is basically the inverse of `factor`.
  //
  // Since only the deleted portions of the union string are necessary,
  // instead of requiring a union string the function takes a `tombstones`
  // rope which contains the deleted portions of the union string. The
  // `from_dels` subset must be the interleaving of `tombstones` into the
  // union string.
  //
  // ```no_run
  // # use xi_rope::rope::{Rope, RopeInfo};
  // # use xi_rope::delta::Delta;
  // # use std::str::FromStr;
  // fn test_synthesize(d : &Delta<RopeInfo>, r : &Rope) {
  //     let (ins_d, del) = d.clone().factor();
  //     let ins = ins_d.inserted_subset();
  //     let del2 = del.transform_expand(&ins);
  //     let r2 = ins_d.apply(&r);
  //     let tombstones = ins.complement().delete_from(&r2);
  //     let d2 = Delta::synthesize(&tombstones, &ins, &del);
  //     assert_eq!(String::from(d2.apply(r)), String::from(d.apply(r)));
  // }
  // ```
  static func synthesize(_ tombstones: Node<N>, _ from_dels: Subset, _ to_dels: Subset) -> Delta<N>
  {
    let base_len = from_dels.len_after_delete()
    var els = [DeltaElement<N>]()
    var x: UInt = 0
    var old_ranges = from_dels.complement_iter()
    var last_old = old_ranges.next()
    var m = from_dels.mapper(CountMatcher.NonZero)
    // For each segment of the new text
    for (b, e) in to_dels.complement_iter() {
      // Fill the whole segment
      var beg = b
      while beg < e {
        // Skip over ranges in old text until one overlaps where we want to fill
        while true {
          if last_old == nil {
            break
          }
          let ib = last_old!.0
          let ie = last_old!.1
          if ie > beg {
            break
          }
          x += ie - ib
          last_old = old_ranges.next()
        }
        // If we have a range in the old text with the character at beg, then we Copy
        if last_old != nil && last_old!.0 <= beg {
          let (ib, ie) = last_old!
          let end = min(e, ie)
          // Try to merge contiguous Copys in the output
          let xbeg = beg + x - ib  // "beg - ib + x" better for overflow?
          let xend = end + x - ib  // ditto
          var merged = false
          var newlb: UInt = 0
          var newle: UInt = 0
          switch els.last {
          case .some(let elt):
            switch elt {
            case .Copy(let lb, let le):
              if le == xbeg {
                merged = true
                newlb = lb
                newle = xend
              }
            case .Insert(_): break
            }
          case .none: break
          }
          if merged {
            els[els.count - 1] = .Copy(newlb, newle)
          }
          if !merged {
            els.append(DeltaElement.Copy(xbeg, xend))
          }
          beg = end
        } else {
          // if the character at beg isn't in the old text, then we Insert
          // Insert up until the next old range we could Copy from, or the end of this segment
          var end = e
          if case let .some((ib, _)) = last_old {
            end = min(end, ib)
          }
          // Note: could try to aggregate insertions, but not sure of the win.
          // Use the mapper to insert the corresponding section of the tombstones rope
          let interval =
            Interval(m.doc_index_to_subset(beg), m.doc_index_to_subset(end))
          els.append(.Insert(tombstones.subseq(interval)))
          beg = end
        }
      }
    }
    return Delta(els, base_len)
  }

  // Produce a summary of the delta. Everything outside the returned interval
  // is unchanged, and the old contents of the interval are replaced by new
  // contents of the returned length. Equations:
  //
  // `(iv, new_len) = self.summary()`
  //
  // `new_s = self.apply(s)`
  //
  // `new_s = simple_edit(iv, new_s.subseq(iv.start(), iv.start() + new_len), s.len()).apply(s)`
  func summary() -> (Interval, UInt) {
    var iv_start = 0
    var els = ArraySlice(self.els)
    let split_first = els.split_first()
    if split_first != nil {
      let (first, rest) = split_first!
      if case .Copy(0, let end) = first[0] {
        iv_start = Int(end)
        els = rest
      }
    }
    var iv_end = self.base_len
    let split_last = els.split_last()
    if split_last != nil {
      let (last, initi) = split_last!
      if case .Copy(let beg, let end) = last[0] {
        if end == iv_end {
          iv_end = beg
          els = initi
        }
      }
    }
    return (Interval(UInt(iv_start), iv_end), Delta.total_element_len(els))
  }
}

struct InsertDelta<N: NodeInfo> {
  var elem: Delta<N>
  var base_len: UInt {
    return elem.base_len
  }

  // Do a coordinate transformation on an insert-only delta. The `after` parameter
  // controls whether the insertions in `self` come after those specific in the
  // coordinate transform.
  //
  // TODO: write accurate equations
  func transform_expand(_ xform: Subset, _ after: Bool) -> InsertDelta<N> {
    let cur_els = self.elem.els
    var els = [DeltaElement<N>]()
    var x: UInt = 0  // coordinate within self
    var y: UInt = 0  // coordinate within xform
    var i: UInt = 0  // index into self.els
    var b1: UInt = 0
    var xform_ranges = xform.complement_iter()
    var last_xform = xform_ranges.next()
    let l = xform.count(CountMatcher.All)
    while y < l || i < cur_els.count {
      let next_iv_beg = last_xform != nil ? last_xform!.0 : l
      if after && y < next_iv_beg {
        y = next_iv_beg
      }
      innerloop: while i < cur_els.count {
        switch cur_els[Int(i)] {
        case DeltaElement.Insert(let n):
          if y > b1 {
            els.append(DeltaElement.Copy(b1, y))
          }
          b1 = y
          els.append(DeltaElement.Insert(n))
          i += 1
        case DeltaElement.Copy(_, let e):
          if y >= next_iv_beg {
            var next_y = e + y - x
            if case let .some((_, xe)) = last_xform {
              next_y = min(next_y, xe)
            }
            x += next_y - y
            y = next_y
            if x == e {
              i += 1
            }
            if case let .some((_, xe)) = last_xform {
              if y == xe {
                last_xform = xform_ranges.next()
              }
            }
          }
          break innerloop
        }
      }
      if !after && y < next_iv_beg {
        y = next_iv_beg
      }
    }
    if y > b1 {
      els.append(DeltaElement.Copy(b1, y))
    }
    return InsertDelta(elem: Delta(els, l))
  }

  // TODO: it is plausible this method also works on Deltas with deletes
  /// Shrink a delta through a deletion of some of its copied regions with
  /// the same base. For example, if `self` applies to a union string, and
  /// `xform` is the deletions from that union, the resulting Delta will
  /// apply to the text.
  func transform_shrink(_ xform: Subset) -> InsertDelta<N> {
    var m = xform.mapper(CountMatcher.Zero)
    let els = self
      .elem
      .els
      .map({ elem -> DeltaElement<N> in
        switch elem {
        case DeltaElement.Copy(let b, let e):
          return DeltaElement.Copy(m.doc_index_to_subset(b), m.doc_index_to_subset(e))
        case DeltaElement.Insert(let n):
          return DeltaElement.Insert(n.clone())
        }
      })
    return InsertDelta(elem: Delta(els, xform.len_after_delete()))
  }

  /// Apply the delta to the given rope. May not work well if the length of the rope
  /// is not compatible with the construction of the delta.
  func apply(_ base: Node<N>) -> Node<N> {
    assert(base.len() == self.base_len, "must apply Delta to Node of correct length")
    var b = TreeBuilder<N>()
    for elem in self.elem.els {
      switch elem {
      case let DeltaElement.Copy(beg, end):
        base.push_subseq(b: &b, iv: Interval(beg, end))
      case DeltaElement.Insert(let n):
        b.push(n: n.clone())
      }
    }
    return b.build()
  }

  // Return a Subset containing the inserted ranges.
  //
  // `d.inserted_subset().delete_from_string(d.apply_to_string(s)) == s`
  func inserted_subset() -> Subset {
    var sb = SubsetBuilder()
    for elem in self.elem.els {
      switch elem {
      case .Copy(let b, let e):
        sb.push_segment(e - b, 0)
      case DeltaElement.Insert(let n):
        sb.push_segment(n.len(), 1)
      }
    }
    return sb.build()
  }
}

struct DeltaBuilder<N: NodeInfo> {
  var delta: Delta<N>
  var last_offset: UInt

  init(_ base_len: UInt) {
    self.delta = Delta([], base_len)
    self.last_offset = 0
  }

  mutating func delete<T: IntervalBounds>(_ interval: T) {
    let interval = interval.into_interval(upper_bound: delta.base_len)
    let (start, end) = interval.start_end()
    assert(start >= self.last_offset, "Delta builder: intervals not properly sorted")
    if start > self.last_offset {
      self.delta.els.append(DeltaElement.Copy(self.last_offset, start))
    }
    self.last_offset = end
  }

  mutating func replace<T: IntervalBounds>(_ interval: T, _ rope: Node<N>) {
    self.delete(interval)
    if !rope.is_empty() {
      self.delta.els.append(DeltaElement.Insert(rope))
    }
  }

  mutating func build() -> Delta<N> {
    if self.last_offset < self.delta.base_len {
      self.delta.els.append(DeltaElement.Copy(self.last_offset, self.delta.base_len))
    }
    return self.delta
  }

  /// Determines if delta would be a no-op transformation if built.
  func is_empty() -> Bool {
    return self.last_offset == 0 && self.delta.els.isEmpty
  }
}

// A mapping from coordinates in the source sequence to coordinates in the sequence after
// the delta is applied.
// TODO: this doesn't need the new strings, so it should either be based on a new structure
// like Delta but missing the strings, or perhaps the two subsets it's synthesized from.
struct Transformer<N: NodeInfo> {
  var delta: Delta<N>

  init(_ delta: Delta<N>) {
    self.delta = delta
  }

  // TODO: implement a cursor so we're not scanning from the beginning every time.
  mutating func transform(_ ix: UInt, _ after: Bool) -> UInt {
    if ix == 0 && !after {
      return 0
    }
    var result: UInt = 0
    for el in self.delta.els {
      switch el {
      case let .Copy(beg, end):
        if ix <= beg {
          return result
        }
        if ix < end || (ix == end && !after) {
          return result + ix - beg
        }
        result += end - beg
      case .Insert(let n):
        result += n.len()
      }
    }
    return result
  }
}
