//
//  View.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 7/7/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
//  Its actually a direct translation of View from
//  https://github.com/xi-editor/xi-editor/blob/master/rust/core-lib/src/view.rs
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

struct View: Codable, Equatable {

    let view_id: ViewId
    let buffer_id: BufferId

    /// Tracks whether this view has been scheduled to render.
    /// We attempt to reduce duplicate renders by setting a small timeout
    /// after an edit is applied, to allow batching with any plugin updates.
    //let pending_render: Bool
    //let size: Size
    /// The selection state for this view. Invariant: non-empty.
    let selection: Selection

    // let drag_state: Option<DragState>,

    /// vertical scroll position
    let first_line: UInt
    /// height of visible portion
    let height: UInt
    let lines: LinesW

    /// Front end's line cache state for this view. See the `LineCacheShadow`
    /// description for the invariant.
    // let lc_shadow: LineCacheShadow

    /// New offset to be scrolled into position after an edit.
    let scroll_to: UInt?

    /// The state for finding text for this view.
    /// Each instance represents a separate search query.
    // let find: [Find]

    /// Tracks the IDs for additional search queries in find.
    // let find_id_counter: Counter

    /// Tracks whether there has been changes in find results or find parameters.
    /// This is used to determined whether FindStatus should be sent to the frontend.
    // find_changed: FindStatusChange

    /// Tracks the progress of incremental find.
    // find_progress: FindProgress

    /// Tracks whether find highlights should be rendered.
    /// Highlights are only rendered when search dialog is open.
    // let highlight_find: Bool

    /// The state for replacing matches for this view.
    // let replace: Option<Replace>

    /// Tracks whether the replacement string or replace parameters changed.
    // let replace_changed: Bool

    /// Annotations provided by plugins.
    // let annotations: AnnotationStore

    init(view_id: ViewId, buffer_id: BufferId) {
        self.view_id = view_id
        self.buffer_id = buffer_id
        // pending_render = false,
        self.selection = Selection.from(SelRegion.caret(0))
        self.scroll_to = .some(0)
        //size: Size::default(),
        //drag_state: None,
        self.first_line = 0
        self.height = 10
        self.lines = LinesW.def()
        //lc_shadow: LineCacheShadow::default(),
        //find: Vec::new(),
        //find_id_counter: Counter::default(),
        //find_changed: FindStatusChange::None,
        //find_progress: FindProgress::Ready,
        //highlight_find: false,
        //replace: None,
        //replace_changed: false,
        //annotations: AnnotationStore::new(),
    }

    func sel_regions() -> [SelRegion] {
        return self.selection.regions
    }

    // How should we count "column"? Valid choices include:
    // * Unicode codepoints
    // * grapheme clusters
    // * Unicode width (so CJK counts as 2)
    // * Actual measurement in text layout
    // * Code units in some encoding
    //
    // Of course, all these are identical for ASCII. For now we use UTF-8 code units
    // for simplicity.

    func offset_to_line_col(_ text: Rope, _ offset: UInt) -> (UInt, UInt) {
        let line = self.line_of_offset(text, offset)
        return (line, offset - self.offset_of_line(text, line))
    }

    /// Returns the visible line number containing the given offset.
    func line_of_offset(_ text: Rope, _ offset: UInt) -> UInt {
        return self.lines.visual_line_of_offset(text, offset)
    }

    func offset_of_line(_ text: Rope, _ line: UInt) -> UInt {
        return self.lines.offset_of_visual_line(text, line)
    }

    /// Updates the view after the text has been modified by the given `delta`.
    /// This method is responsible for updating the cursors, and also for
    /// recomputing line wraps.
    mutating func after_edit(
        _ text: Rope,
        _ last_text: Rope,
        _ delta: RopeDelta,
        //client: &Client,
        //width_cache: &mut WidthCache,
        _ drift: InsertDrift
    ) {
        //let visible = self.first_line..<self.first_line + self.height
        /*match self.lines.after_edit(text, last_text, delta, width_cache, client, visible) {
            Some(InvalLines { start_line, inval_count, new_count }) => {
                self.lc_shadow.edit(start_line, start_line + inval_count, new_count);
            }
            None => self.set_dirty(text),
        }*/

        // Any edit cancels a drag. This is good behavior for edits initiated through
        // the front-end, but perhaps not for async edits.
        // self.drag_state = nil

        let (iv, _) = delta.summary()
        // self.annotations.invalidate(iv);

        // update only find highlights affected by change
        /*for find in &mut self.find {
            find.update_highlights(text, delta);
            self.find_changed = FindStatusChange::All;
        }*/

        // Note: for committing plugin edits, we probably want to know the priority
        // of the delta so we can set the cursor before or after the edit, as needed.
        let new_sel = self.selection.apply_delta(delta, true, drift)
        self.set_selection_for_edit(text, new_sel)
    }


    static func == (lhs: View, rhs: View) -> Bool {
        return lhs.lines == rhs.lines
    }
}
