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

    func deleteBackward() {
        editor.delete_backward(&view, CRDT.config)
    }

    func insert(chars: String) {
        editor.insert(&view, Rope.from_str(chars))
    }

    static func == (lhs: CRDT, rhs: CRDT) -> Bool {
        return lhs.editor == rhs.editor && lhs.view == rhs.view
    }
}
