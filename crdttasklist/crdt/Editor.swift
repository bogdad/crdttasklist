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

class EditorBox: NSObject, NSCoding {
    func encode(with coder: NSCoder) {
        coder.encode(editor.text, forKey: PropertyKey.text)
        coder.encode(editor.last_rev_id, forKey: PropertyKey.lastRevId)
        coder.encode(editor.pristine_rev_id, forKey: PropertyKey.pristineRevId)
        coder.encode(editor.undo_group_id, forKey: PropertyKey.undoGroupId)
        coder.encode(editor.live_undos, forKey: PropertyKey.liveUndos)
        coder.encode(editor.cur_undo, forKey: PropertyKey.curUndo)
        coder.encode(editor.gc_undos, forKey: PropertyKey.gcUndos)
        coder.encode(editor.force_undo_group, forKey: PropertyKey.forceUndoGroup)
        coder.encode(editor.this_edit_type, forKey: PropertyKey.thisEditType)
        coder.encode(editor.last_edit_type, forKey: PropertyKey.lastEditType)
        coder.encode(editor.revs_in_flight, forKey: PropertyKey.revsInFlight)
    }

    required convenience init?(coder: NSCoder) {
        guard let text = coder.decodeObject(forKey: PropertyKey.text) as? String
        else {
        return nil
        }
        self.init(Editor(text))
    }

    var editor: Editor
    init(_ editor: Editor) {
        self.editor = editor
    }

    struct PropertyKey {
        static let text = "text"
        static let lastRevId = "last_rev_id"
        static let pristineRevId = "pristine_rev_id"
        static let undoGroupId = "undo_group_id"
        static let liveUndos = "live_undo"
        static let curUndo = "cur_undo"
        static let gcUndos = "gc_undos"
        static let forceUndoGroup = "force_undo_group"
        static let thisEditType = "this_edit_type"
        static let lastEditType = "last_edit_type"
        static let revsInFlight = "revs_in_flight"
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

    init(_ text: String) {
        let engine = Engine.new(Rope.from_str(text[...]))
        let buffer = engine.get_head()
        let last_rev_id = engine.get_head_rev_id();
        self.text = buffer
        self.engine = engine
        self.last_rev_id = last_rev_id
        self.pristine_rev_id = last_rev_id
        self.undo_group_id = 1
        // GC only works on undone edits or prefixes of the visible edits,
        // but initial file loading can create an edit with undo group 0,
        // so we want to collect that as part of the prefix.
        self.live_undos = [0]
        self.cur_undo = 1
        self.undos = SortedSet()
        self.gc_undos = SortedSet()
        self.force_undo_group = false
        self.last_edit_type = .Other
        self.this_edit_type = .Other
        // self.layers = Layers.default()
        self.revs_in_flight = 0
        // self.sync_store = nil
        // self.last_synced_rev = last_rev_id,
    }

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
        let priority: UInt = 0x10000;
        self.engine.edit_rev(priority, undo_group, head_rev_id.token(), delta)
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

    func get_head_rev_token() -> UInt64 {
        return self.engine.get_head_rev_id().token()
    }

    func get_buffer() -> Rope {
        return self.text
    }
}
