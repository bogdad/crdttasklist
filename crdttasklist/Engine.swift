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
typealias RevToken = UInt64

/// Type for errors that occur during CRDT operations.
enum CrdtError: Error {
    /// An edit specified a revision that did not exist. The revision may
    /// have been GC'd, or it may have specified incorrectly.
    case MissingRevision(RevToken)
    /// A delta was applied which had a `base_len` that did not match the length
    /// of the revision it was applied to.
    case MalformedDelta(rev_len: UInt, delta_len: UInt)
}

enum Contents {
    case Edit(priority: UInt,
    /// Groups related edits together so that they are undone and re-done
    /// together. For example, an auto-indent insertion would be un-done
    /// along with the newline that triggered it.
    undo_group: UInt,
    /// The subset of the characters of the union string from after this
    /// revision that were added by this revision.
    inserts: Subset,
    /// The subset of the characters of the union string from after this
    /// revision that were deleted by this revision.
    deletes: Subset)
    case Undo(
        toggled_groups: SortedSet<UInt>, // set of undo_group id's
        /// Used to store a reversible difference between the old
        /// and new deletes_from_union
        deletes_bitxor: Subset
    )
}

struct FullPriority {
    static func >= (lhs: FullPriority, rhs: FullPriority) -> Bool {
        return lhs.priority >= rhs.priority && lhs.session_id >= rhs.session_id
    }

    var priority: UInt
    var session_id: SessionId
    init(priority: UInt, session_id: SessionId) {
        self.priority = priority
        self.session_id = session_id
    }
}


struct RevId: Hashable {
    // 96 bits has a 10^(-12) chance of collision with 400 million sessions and 10^(-6) with 100 billion.
    // `session1==session2==0` is reserved for initialization which is the same on all sessions.
    // A colliding session will break merge invariants and the document will start crashing Xi.
    var session1: UInt64
    // if this was a tuple field instead of two fields, alignment padding would add 8 more bytes.
    var session2: UInt32
    // There will probably never be a document with more than 4 billion edits
    // in a single session.
    var num: UInt32

    init(session1: UInt64, session2: UInt32, num: UInt32) {
        self.session1 = session1
        self.session2 = session2
        self.num = num
    }

    func token() -> RevToken {
        // Rust is unlikely to break the property that this hash is strongly collision-resistant
        // and it only needs to be consistent over one execution.
        var hasher = Hasher64()
        hasher.combine(session1)
        hasher.combine(session2)
        hasher.combine(num)
        return hasher.finalize()
    }

    func session_id() -> SessionId {
        return (self.session1, self.session2)
    }
}

struct Revision {
    /// This uniquely represents the identity of this revision and it stays
    /// the same even if it is rebased or merged between devices.
    var rev_id: RevId
    /// The largest undo group number of any edit in the history up to this
    /// point. Used to optimize undo to not look further back.
    var max_undo_so_far: UInt
    var edit: Contents

    init(rev_id: RevId, edit: Contents, max_undo_so_far: UInt) {
        self.rev_id = rev_id
        self.edit = edit
        self.max_undo_so_far = max_undo_so_far
    }
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
    var deletes_from_union: Cow<Subset>
    // TODO: switch to a persistent Set representation to avoid O(n) copying
    var undone_groups: Cow<SortedSet<UInt>> // set of undo_group id's
    /// The revision history of the document
    var revs: [Revision]

    init() {
        let deletes_from_union = Subset.make_empty(0)
        let rev = Revision(
            rev_id: RevId(session1: 0, session2: 0, num: 0),
            edit: Contents.Undo(
                toggled_groups: SortedSet(),
                deletes_bitxor: deletes_from_union.clone()
            ),
            max_undo_so_far: 0)
        self.session = Engine.default_session()
        self.rev_id_counter = 1
        self.text = Rope.def()
        self.tombstones = Rope.def()
        self.deletes_from_union = Cow(deletes_from_union)
        self.undone_groups = Cow(SortedSet())
        self.revs = [rev]
    }

    static func make_from_rope(_ initial_contents: Rope) -> Engine {
        var engine = Engine()
        if !initial_contents.is_empty() {
            let first_rev = engine.get_head_rev_id().token()
            let delta = Delta.simple_edit(Interval(0, 0), initial_contents, 0)
            engine.edit_rev(0, 0, first_rev, delta)
        }
        return engine
    }

    func get_head_rev_id() -> RevId {
        return self.revs.last!.rev_id
    }

    /// Get text of head revision.
    func get_head() -> Rope {
        return self.text
    }

    func next_rev_id() -> RevId {
        return RevId(session1: self.session.0, session2: self.session.1, num: self.rev_id_counter)
    }

    func find_rev_token(_ rev_token: RevToken) -> UInt? {
        return self.revs
            .makeIterator()
            .enumerated()
            .reversed()
            .first(where: { $0.1.rev_id.token() == rev_token})
            .map {  UInt($0.0) }
    }

    // NOTE: maybe just deprecate this? we can panic on the other side of
    // the call if/when that makes sense.
    /// Create a new edit based on `base_rev`.
    ///
    /// # Panics
    ///
    /// Panics if `base_rev` does not exist, or if `delta` is poorly formed.
    mutating func edit_rev(_ priority: UInt, _ undo_group: UInt, _ base_rev: RevToken, _ delta: Delta<RopeInfo>) {
         let res = self.try_edit_rev(priority, undo_group, base_rev, delta)
        switch res {
        case .success(()):
            return
        case .failure(let err):
            fatalError("edit_rev error " + err.localizedDescription)
        }
    }

    mutating func try_edit_rev(_ priority: UInt, _ undo_group: UInt, _ base_rev: RevToken, _ delta: Delta<RopeInfo>) -> Result<(), CrdtError> {
        let res = self.mk_new_rev(priority, undo_group, base_rev, delta)
        if case let .failure(err) = res {
            return .failure(err)
        }
        if case let .success(tpl) = res {
            let (new_rev, new_text, new_tombstones, new_deletes_from_union) = tpl
            self.rev_id_counter += 1
            self.revs.append(new_rev)
            self.text = new_text
            self.tombstones = new_tombstones
            self.deletes_from_union.value = new_deletes_from_union
        }
        return .success(())
    }

    func mk_new_rev(
    _ new_priority: UInt,
    _ undo_group: UInt,
    _ base_rev: RevToken,
    _ delta: Delta<RopeInfo>) -> Result<(Revision, Rope, Rope, Subset), CrdtError> {

        let revtoken = self.find_rev_token(base_rev)
        if (revtoken == nil) {
            return .failure(CrdtError.MissingRevision(base_rev))
        }
        let ix = revtoken!
        let (ins_delta, deletes) = delta.factor()

        // rebase delta to be on the base_rev union instead of the text
        var deletes_at_rev = self.deletes_from_union_for_index(rev_index: ix)

        // validate delta
        if ins_delta.elem.base_len != deletes_at_rev.value.len_after_delete() {
            return .failure(CrdtError.MalformedDelta(
                rev_len: deletes_at_rev.value.len_after_delete(),
                delta_len: ins_delta.base_len
                ))
        }

        var union_ins_delta = ins_delta.transform_expand(deletes_at_rev, true)
        var new_deletes = Cow(deletes.transform_expand(deletes_at_rev))

        // rebase the delta to be on the head union instead of the base_rev union
        // FIXME: Cow is a mess here!
        let new_full_priority = FullPriority(priority: new_priority, session_id: self.session)
        for r in self.revs[Int(ix + 1)...] {
            if case let Contents.Edit(priority: priority, undo_group: _, inserts: inserts, deletes: _) = r.edit {
                if !inserts.is_empty() {
                    let full_priority =
                        FullPriority(priority: priority, session_id: r.rev_id.session_id())
                    let after = new_full_priority >= full_priority // should never be ==
                    union_ins_delta = union_ins_delta.transform_expand(Cow(inserts), after)
                    new_deletes.value = new_deletes.value.transform_expand(Cow(inserts))
                }
            }
        }

        // rebase the deletion to be after the inserts instead of directly on the head union
        let new_inserts = Cow(union_ins_delta.inserted_subset())
        if !new_inserts.value.is_empty() {
            new_deletes.value = new_deletes.value.transform_expand(new_inserts)
        }

        // rebase insertions on text and apply
        let cur_deletes_from_union = self.deletes_from_union
        let text_ins_delta = union_ins_delta.transform_shrink(cur_deletes_from_union)
        let text_with_inserts = text_ins_delta.apply(self.text)
        var rebased_deletes_from_union = cur_deletes_from_union.value.transform_expand(new_inserts)

        // is the new edit in an undo group that was already undone due to concurrency?
        let undone = self.undone_groups.value.contains(undo_group)
        var to_delete = undone ? new_inserts : new_deletes
        var new_deletes_from_union = rebased_deletes_from_union.union(&to_delete.value)

        // move deleted or undone-inserted things from text to tombstones
        let (new_text, new_tombstones) = GenericHelpers.shuffle(
        text_with_inserts, self.tombstones, &rebased_deletes_from_union, &new_deletes_from_union)

        let head_rev = self.revs[revs.count - 1]
        return .success((
            Revision(
                rev_id: self.next_rev_id(),
                edit: .Edit(
                    priority: new_priority,
                    undo_group: undo_group,
                    // FIXME: move instead of copy
                    inserts: new_inserts.value,
                    deletes: new_deletes.value
                ),
                max_undo_so_far: max(undo_group, head_rev.max_undo_so_far)),
                new_text,
                new_tombstones,
                new_deletes_from_union
        ))
    }

    // TODO: does Cow really help much here? It certainly won't after making Subsets a rope.
    /// Find what the `deletes_from_union` field in Engine would have been at the time
    /// of a certain `rev_index`. In other words, the deletes from the union string at that time.
    func deletes_from_union_for_index(rev_index: UInt) -> Cow<Subset> {
        return self.deletes_from_union_before_index(rev_index + 1, true)
    }

    func deletes_from_union_before_index(_ rev_index: UInt, _ invert_undos: Bool) -> Cow<Subset> {
        var deletes_from_union = self.deletes_from_union
        var undone_groups = self.undone_groups

        // invert the changes to deletes_from_union starting in the present and working backwards
        for rev in self.revs[Int(rev_index)...].makeIterator().reversed() {
            switch rev.edit {
            case .Edit(_, let undo_group, var inserts, var deletes):
                if undone_groups.value.contains(undo_group) {
                    // no need to un-delete undone inserts since we'll just shrink them out
                    deletes_from_union = Cow(deletes_from_union.value.transform_shrink(&inserts))
                } else {
                    let un_deleted = deletes_from_union.value.subtract(&deletes)
                    deletes_from_union = Cow(un_deleted.transform_shrink(&inserts))
                }
            case .Undo(let toggled_groups, var deletes_bitxor):
                if invert_undos {
                    let new_undone =
                        undone_groups.value.symmetricDifference(toggled_groups)
                    undone_groups = Cow(new_undone)
                    deletes_from_union = Cow(deletes_from_union.value.bitxor(&deletes_bitxor))
                }
            }
        }
        return deletes_from_union
    }

    static func default_session() -> (UInt64, UInt32) {
        return (1, 0)
    }
}

struct GenericHelpers {

    /// Move sections from text to tombstones and out of tombstones based on a new and old set of deletions
    static func shuffle_tombstones(
    _ text: Rope,
    _ tombstones: Rope,
    _ old_deletes_from_union: inout Subset,
    _ new_deletes_from_union: inout Subset
    ) -> Rope {
        // Taking the complement of deletes_from_union leads to an interleaving valid for swapped text and tombstones,
        // allowing us to use the same method to insert the text into the tombstones.
        var inverse_tombstones_map = old_deletes_from_union.complement()
        var new_deletes_from_union_complement = new_deletes_from_union.complement()
        let move_delta =
            Delta.synthesize(text, &inverse_tombstones_map, &new_deletes_from_union_complement)
        return move_delta.apply(tombstones)
    }


    /// Move sections from text to tombstones and vice versa based on a new and old set of deletions.
    /// Returns a tuple of a new text `Rope` and a new `Tombstones` rope described by `new_deletes_from_union`.
    static func shuffle(
                    _ text: Rope,
                    _ tombstones: Rope,
                    _ old_deletes_from_union: inout Subset,
                    _ new_deletes_from_union: inout Subset
    ) -> (Rope, Rope) {
        // Delta that deletes the right bits from the text
        let del_delta = Delta.synthesize(tombstones, &old_deletes_from_union, &new_deletes_from_union)
        let new_text = del_delta.apply(text)
        // println!("shuffle: old={:?} new={:?} old_text={:?} new_text={:?} old_tombstones={:?}",
        //     old_deletes_from_union, new_deletes_from_union, text, new_text, tombstones);
        return (new_text, shuffle_tombstones(text, tombstones, &old_deletes_from_union, &new_deletes_from_union))
    }
}
