//
//  TestHelpers.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 8/8/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
// Its actually a direct translation of Rope from
//  https://github.com/xi-editor/xi-editor/blob/master/rust/rope/src/test_helpers.rs
// to Swift
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

class TestHelpers {
  // Creates a `Subset` of `s` by scanning through `substr` and finding which
  // characters of `s` are missing from it in order. Returns a `Subset` which
  // when deleted from `s` yields `substr`.
  static func find_deletions(_ substr: String, _ s: String) -> Subset {
    var sb = SubsetBuilder()
    var j: UInt = 0
    for i: UInt in 0..<UInt(s.count) {
      if j < substr.count {
        let substr_j = substr.index(substr.startIndex, offsetBy: Int(j))
        let s_i = s.index(s.startIndex, offsetBy: Int(i))
        if substr[substr_j] == s[s_i] {
          j += 1
        } else {
          sb.add_range(i, i + 1, 1)
        }
      } else {
        sb.add_range(i, i + 1, 1)
      }
    }
    sb.pad_to_len(s.len())
    return sb.build()
  }

  static func parse_subset(_ s: String) -> Subset {
    var sb = SubsetBuilder()

    for c in s.chars() {
      if c == "#".chars()[0] {
        sb.push_segment(1, 1)
      } else if c == "e".chars()[0] {
        // do nothing, used for empty subsets
      } else {
        sb.push_segment(1, 0)
      }
    }
    return sb.build()
  }

  static func parse_subset_list(_ s: String) -> [Subset] {
    return s.lines
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .map { parse_subset($0) }
  }

  static func debug_subsets(_ subsets: [Subset]) {
    for s in subsets {
      print("\(s.dbg())")
    }
  }

  static func parse_delta(_ s: String) -> Delta<RopeInfo> {
    let minus: Character = "-"
    let exc: Character = "!"
    let base_len =
      s
      .chars()
      .filter { $0 == minus.asciiValue! || $0 == exc.asciiValue! }
      .count
    var b = DeltaBuilder<RopeInfo>(UInt(base_len))

    var i = 0
    for c in s {
      if c == minus {
        i += 1
      } else if c == exc {
        b.delete(Interval(UInt(i), UInt(i + 1)))
        i += 1
      } else {
        let inserted = "\(c)"
        b.replace(Interval(UInt(i), UInt(i)), Rope.from_str(inserted))
      }
    }

    return b.build()
  }
}
