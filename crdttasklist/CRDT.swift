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

    func deleteBackward() {
         editor.delete_backward(&view, CRDT.config)
        after_edit()
    }

    func insert(chars: String) {
        editor.insert(&view, Rope.from_str(chars))
        print("cur: \(editor.get_buffer())")
        after_edit()
    }

    static func == (lhs: CRDT, rhs: CRDT) -> Bool {
        return lhs.editor == rhs.editor && lhs.view == rhs.view
    }

    /// Commits any changes to the buffer, updating views and plugins as needed.
    /// This only updates internal state; it does not update the client.
    func after_edit() {

        let edit_info = editor.commit_delta()
        guard let (delta, last_text, drift) = edit_info else {
            return
        }

        self.update_views(delta, last_text, drift)
    }


    func update_views(_ delta: RopeDelta, _ last_text: Rope, _ drift: InsertDrift) {
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
}
