//
//  LineWrap.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 7/7/19.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//
//  Its actually a direct translation of View from
//  https://github.com/xi-editor/xi-editor/blob/master/rust/core-lib/src/linewrap.rs
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

enum WrapWidth: Equatable {
    /// No wrapping in effect.
    case None

    /// Width in bytes (utf-8 code units).
    ///
    /// Only works well for ASCII, will probably not be maintained long-term.
    case Bytes(UInt)

    /// Width in px units, requiring measurement by the front-end.
    case Width(Double)
}

struct LinesW {
    var wrap: WrapWidth

    func visual_line_of_offset(_ text: Rope, _ offset: UInt) -> UInt {
        var line = text.line_of_offset(offset)
        if self.wrap != WrapWidth.None {
            line += self.breaks.count(BreaksMetric.self, offset)
        }
        return line
    }

    static func def() -> LinesW {
        return LinesW(wrap: WrapWidth.None)
    }

}
