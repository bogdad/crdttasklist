//
//  Editor.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 7/7/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//

import Foundation

struct Editor {
    /// The contents of the buffer.
    var text: Rope
    /// The CRDT engine, which tracks edit history and manages concurrent edits.
    //engine: Engine,

    /// The most recent revision.
    //last_rev_id: RevId,
    /// The revision of the last save.
    //pristine_rev_id: RevId,
    var undo_group_id: UInt
    /// Undo groups that may still be toggled
    var live_undos: [UInt]
    /// The index of the current undo; subsequent undos are currently 'undone'
    /// (but may be redone)
    var cur_undo: UInt
    /// undo groups that are undone
    var undos: BTreeSet<UInt>
    /// undo groups that are no longer live and should be gc'ed
    gc_undos: BTreeSet<UInt>
    force_undo_group: Bool

    //this_edit_type: EditType,
    //last_edit_type: EditType,

    //revs_in_flight: UInt,

    /// Used only on Fuchsia for syncing
    #[allow(dead_code)]
    //sync_store: Option<SyncStore>,
    #[allow(dead_code)]
    //last_synced_rev: RevId,

    //layers: Layers,
}
