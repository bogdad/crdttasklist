//
//  CRDT.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-03-15.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

class CRDT: Codable, Equatable {
    var editor: Editor
    var view: View
    static let config = BufferItems()

    init(_ s: String) {
        self.editor = Editor(s)
        self.view = View(view_id: 0, buffer_id: 0)
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

    func editing_finished() {
        view.reset_selection()
    }

    func merge(_ other: CRDT) -> CRDTMergeResult {
        let editorMerge = self.editor.merge(other.editor.engine)
        return CRDTMergeResult(selfChanged: editorMerge.selfChanged, otherChanged: editorMerge.newChanged)
    }

    func replace(_ range: Interval, _ str: String) {
        set_position(range)

        if range.len() > 0 {
            deleteBackward()
        }

        insert(str)
    }

    private func position() -> Interval {
        return view.selection.regions[0].to_interval()
    }

    private func set_position(_ r: Interval) {
        view.set_selection_for_edit(Selection.new_simple(SelRegion.from(r)))
    }

    private func update_views(_ delta: RopeDelta, _ last_text: Rope, _ drift: InsertDrift) {
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

    private func deleteBackward() {
        editor.delete_backward(&view, CRDT.config)
        after_edit()
    }

    private func insert(_ chars: String) {
        editor.insert(&view, Rope.from_str(chars))
        after_edit()
    }

    /// Commits any changes to the buffer, updating views and plugins as needed.
    /// This only updates internal state; it does not update the client.
    private func after_edit() {

        let edit_info = editor.commit_delta()
        guard let (delta, last_text, drift) = edit_info else {
            return
        }

        self.update_views(delta, last_text, drift)
    }
}

struct CRDTMergeResult {
    let selfChanged: Bool
    let otherChanged: Bool
}
