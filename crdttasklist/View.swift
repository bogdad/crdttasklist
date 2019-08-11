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

struct View {

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
    let lines: Lines

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
        self.lines = Lines.def()
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
}
