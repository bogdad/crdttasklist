//
//  IndexSet.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-03-27.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//
//  Its actually a direct translation of View from
//  https://github.com/xi-editor/xi-editor/blob/master/rust/core-lib/src/index_set.rs
//  to Swift
//
// Copyright 2017 The xi-editor Authors.
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

//! A data structure for manipulating sets of indices (typically used for
//! representing valid lines).

// Note: this data structure has nontrivial overlap with Subset in the rope
// crate. Maybe we don't need both.


import Foundation

struct IndexSet {
    var ranges: [(UInt, UInt)]
}

func remove_n_at<T>(v: [T], index: UInt, n: UInt) {
    match n.cmp(&1) {
        Ordering::Equal => {
            v.remove(index);
        }
        Ordering::Greater => {
            let new_len = v.len() - n;
            for i in index..new_len {
                v[i] = v[i + n].clone();
            }
            v.truncate(new_len);
        }
        Ordering::Less => (),
    }
}
