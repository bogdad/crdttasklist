//
//  Editor.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 7/7/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
//  Its actually a direct translation of Editor from
//  https://github.com/xi-editor/xi-editor/tree/master/rust/core-lib/src/editor.rs
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

struct EditorConstants {
    static let MAX_UNDOS: UInt = 20
}

enum EditType {
    /// A catchall for edits that don't fit elsewhere, and which should
    /// always have their own undo groups; used for things like cut/copy/paste.
    case Other
    /// An insert from the keyboard/IME (not a paste or a yank).
    case InsertChars

    case InsertNewline
    /// An indentation adjustment.
    case Indent
    case Delete
    case Undo
    case Redo
    case Transpose
    case Surround

    func breaks_undo_group(_ previous: EditType) -> Bool {
        return self == EditType.Other || self == EditType.Transpose || self != previous
    }
}



struct Editor {
    /// The contents of the buffer.
    var text: Rope
    /// The CRDT engine, which tracks edit history and manages concurrent edits.
    var engine: Engine

    /// The most recent revision.
    var last_rev_id: RevId
    /// The revision of the last save.
    var pristine_rev_id: RevId

    var undo_group_id: UInt
    /// Undo groups that may still be toggled
    var live_undos: [UInt]
    /// The index of the current undo; subsequent undos are currently 'undone'
    /// (but may be redone)
    var cur_undo: UInt
    /// undo groups that are undone
    var undos: SortedSet<UInt>
    /// undo groups that are no longer live and should be gc'ed
    var gc_undos: SortedSet<UInt>
    var force_undo_group: Bool

    var this_edit_type: EditType
    var last_edit_type: EditType

    var revs_in_flight: UInt

    /// Used only on Fuchsia for syncing
    //#[allow(dead_code)]
    //sync_store: Option<SyncStore>,
    //#[allow(dead_code)]
    //last_synced_rev: RevId,

    // we dont have it yet
    //layers: Layers,

    mutating func insert(view: inout View, rope: Rope) {
        var builder = DeltaBuilder<RopeInfo>(self.text.len())
        for region in view.sel_regions() {
            let iv = Interval(region.min(), region.max())
            builder.replace(iv, rope.clone())
        }
        self.add_delta(builder.build())
    }

    /// Applies a delta to the text, and updates undo state.
    ///
    /// Records the delta into the CRDT engine so that it can be undone. Also
    /// contains the logic for merging edits into the same undo group. At call
    /// time, self.this_edit_type should be set appropriately.
    ///
    /// This method can be called multiple times, accumulating deltas that will
    /// be committed at once with `commit_delta`. Note that it does not update
    /// the views. Thus, view-associated state such as the selection and line
    /// breaks are to be considered invalid after this method, until the
    /// `commit_delta` call.
    mutating func add_delta(_ delta: RopeDelta) {
        let head_rev_id = self.engine.get_head_rev_id()
        let undo_group = self.calculate_undo_group()
        self.last_edit_type = self.this_edit_type
        let priority = 0x10000;
        //self.engine.edit_rev(priority, undo_group, head_rev_id.token(), delta)
        self.text = self.engine.get_head().clone()
    }

    mutating func calculate_undo_group() -> UInt {
        let has_undos = self.live_undos.count > 0
        let force_undo_group = self.force_undo_group
        let is_unbroken_group = !self.this_edit_type.breaks_undo_group(self.last_edit_type)

        if has_undos && (force_undo_group || is_unbroken_group) {
            return self.live_undos.last!
        } else {
            let undo_group = self.undo_group_id;
            // FIXME: can it be made faster?
            for elem in self.live_undos[Int(self.cur_undo)...] {
                self.gc_undos.insert(elem)
            }
            self.live_undos.removeFirst(Int(self.cur_undo))
            self.live_undos.append(undo_group)
            if self.live_undos.count <= EditorConstants.MAX_UNDOS {
                self.cur_undo += 1
            } else {
                self.gc_undos.insert(self.live_undos.remove(at: 0))
            }
            self.undo_group_id += 1
            return undo_group
        }
    }
}
