//
//  CRDT.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-03-15.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

struct CRDT: Codable, Equatable {
    var editor: Editor
    var view: View
    var deletionsInsertions: DeletionsInsertions?
    var lastModificationDate: Date?

    static let config = BufferItems()

    init(_ s: String) {
        self.editor = Editor(s)
        let u64 = UInt64.random(in: 0...UInt64.max)
        let u32 = UInt32.random(in: 0...UInt32.max)
        let sess = (u64, u32)
        self.editor.set_session_id(sess)
        self.view = View(view_id: 0, buffer_id: 0)
        self.deletionsInsertions = DeletionsInsertions()
        self.lastModificationDate = Date()
    }

    mutating func tryMigrate() -> Bool {
        var res = false
        res = res || editor.tryMigrate()
        if self.deletionsInsertions == nil {
            self.deletionsInsertions = DeletionsInsertions()
            res = true
        }
        if self.lastModificationDate == nil {
            self.lastModificationDate = Date()
            res = true
        }
        return res
    }

    func isActive() -> Bool {
        return self.deletionsInsertions?.isActive() ?? true
    }

    func creationDate() -> Date {
        return self.deletionsInsertions?.creationDate() ?? Date()
    }

    func modificationDate() -> Date {
        return self.lastModificationDate ?? Date()
    }

    mutating func markDeleted() {
        deletionsInsertions!.markDeleted()
    }

    func to_string(_ prefix: Int) -> String {
        return editor.get_buffer().slice_to_cow(range: Interval(0, UInt(prefix)))
    }

    func to_string() -> String {
        return to_string(Int(editor.get_buffer().len()))
    }

    static func == (lhs: CRDT, rhs: CRDT) -> Bool {
        return lhs.editor == rhs.editor && lhs.view == rhs.view
    }

    mutating func editing_finished() {
        view.reset_selection()
    }

    mutating func merge(_ other: CRDT) -> CRDTMergeResult {
        let editorMerge = self.editor.merge(other.editor.engine)
        let deletionsMerge = self.deletionsInsertions!.merge(other.deletionsInsertions!)

        var lastModificationDateSelfChanged = false
        var lastModificationDateOtherChanged = false
        let oldSelfDate = lastModificationDate
        lastModificationDate = Swift.max(lastModificationDate!, other.lastModificationDate!)
        if oldSelfDate != lastModificationDate {
            lastModificationDateSelfChanged = true
        }
        if other.lastModificationDate != lastModificationDate {
            lastModificationDateOtherChanged = true
        }

        return CRDTMergeResult(
            selfChanged: editorMerge.selfChanged || deletionsMerge.selfChanged || lastModificationDateSelfChanged,
            otherChanged: editorMerge.newChanged || deletionsMerge.otherChanged || lastModificationDateOtherChanged)
    }

    mutating func replace(_ range: Interval, _ str: String) {
        set_position(range)

        if range.len() > 0 {
            deleteBackward()
        }

        insert(str)
        lastModificationDate = Date()
    }

    private func position() -> Interval {
        return view.selection.regions[0].to_interval()
    }

    mutating private func set_position(_ r: Interval) {
        view.set_selection_for_edit(Selection.new_simple(SelRegion.from(r)))
    }

    mutating private func update_views(_ delta: RopeDelta, _ last_text: Rope, _ drift: InsertDrift) {
        // let mut width_cache = self.width_cache.borrow_mut();
        /*let iter_views = [self.view]//.chain(self.siblings.iter());
        iter_views.for_each({ v in
            view.after_edit(
                ed.get_buffer(),
                last_text,
                delta,
                self.client,
                &mut width_cache,
                drift,
            )
        });*/
        self.view.after_edit(editor.get_buffer(), last_text, delta, drift)
    }

    mutating private func deleteBackward() {
        editor.delete_backward(&view, CRDT.config)
        after_edit()
    }

    mutating private func insert(_ chars: String) {
        editor.insert(&view, Rope.from_str(chars))
        after_edit()
    }

    /// Commits any changes to the buffer, updating views and plugins as needed.
    /// This only updates internal state; it does not update the client.
    mutating private func after_edit() {

        let edit_info = editor.commit_delta()
        guard let (delta, last_text, drift) = edit_info else {
            return
        }

        self.update_views(delta, last_text, drift)
    }
}

