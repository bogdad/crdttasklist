//
//  Engine.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 7/7/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
//  Its actually a direct translation of Engine from
//  https://github.com/xi-editor/xi-editor/blob/master/rust/rope/src/engine.rs
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
import BTree

typealias SessionId = (UInt64, UInt32)

struct Edit {
    var priority: UInt
    /// Groups related edits together so that they are undone and re-done
    /// together. For example, an auto-indent insertion would be un-done
    /// along with the newline that triggered it.
    var undo_group: UInt
    /// The subset of the characters of the union string from after this
    /// revision that were added by this revision.
    var inserts: Subset
    /// The subset of the characters of the union string from after this
    /// revision that were deleted by this revision.
    var deletes: Subset
}

struct Undo {
    var toggled_groups: SortedSet<UInt> // set of undo_group id's
    /// Used to store a reversible difference between the old
    /// and new deletes_from_union
    var deletes_bitxor: Subset
}

// FIXME: is it good in memory?
enum Contents {
    case Edit(edit: Edit)
    case Undo(undo: Undo)
}

struct RevId {
    // 96 bits has a 10^(-12) chance of collision with 400 million sessions and 10^(-6) with 100 billion.
    // `session1==session2==0` is reserved for initialization which is the same on all sessions.
    // A colliding session will break merge invariants and the document will start crashing Xi.
    var session1: UInt64
    // if this was a tuple field instead of two fields, alignment padding would add 8 more bytes.
    var session2: UInt32
    // There will probably never be a document with more than 4 billion edits
    // in a single session.
    var num: UInt32
}

struct Revision {
    /// This uniquely represents the identity of this revision and it stays
    /// the same even if it is rebased or merged between devices.
    var rev_id: RevId
    /// The largest undo group number of any edit in the history up to this
    /// point. Used to optimize undo to not look further back.
    var max_undo_so_far: UInt
    var edit: Contents
}

struct Engine {
    /// The session ID used to create new `RevId`s for edits made on this device
    var session: SessionId
    /// The incrementing revision number counter for this session used for `RevId`s
    var rev_id_counter: UInt32
    /// The current contents of the document as would be displayed on screen
    var text: Rope
    /// Storage for all the characters that have been deleted  but could
    /// return if a delete is un-done or an insert is re- done.
    var tombstones: Rope
    /// Imagine a "union string" that contained all the characters ever
    /// inserted, including the ones that were later deleted, in the locations
    /// they would be if they hadn't been deleted.
    ///
    /// This is a `Subset` of the "union string" representing the characters
    /// that are currently deleted, and thus in `tombstones` rather than
    /// `text`. The count of a character in `deletes_from_union` represents
    /// how many times it has been deleted, so if a character is deleted twice
    /// concurrently it will have count `2` so that undoing one delete but not
    /// the other doesn't make it re-appear.
    ///
    /// You could construct the "union string" from `text`, `tombstones` and
    /// `deletes_from_union` by splicing a segment of `tombstones` into `text`
    /// wherever there's a non-zero-count segment in `deletes_from_union`.
    var deletes_from_union: Subset
    // TODO: switch to a persistent Set representation to avoid O(n) copying
    var undone_groups: SortedSet<UInt> // set of undo_group id's
    /// The revision history of the document
    var revs: [Revision]

    func get_head_rev_id() -> RevId {
        return self.revs.last!.rev_id
    }

    /// Get text of head revision.
    func get_head() -> Rope {
        return self.text
    }
}
