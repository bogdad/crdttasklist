//
//  Backspace.swift
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

//! Calc start of a backspace delete interval
func offset_for_delete_backwards(
    _ view: inout View,
    _ region: inout SelRegion,
    _ text: Rope,
    _ config: BufferItems
) -> UInt {
    if !region.is_caret() {
        return region.min()
    } else {
        // backspace deletes max(1, tab_size) contiguous spaces
        let (_, c) = view.offset_to_line_col(text, region.start)

        let tab_off = c % config.tab_size
        var tab_size = config.tab_size
        if tab_off != 0 {
            tab_size = tab_off
        }

        var tab_start = region.start - tab_size
        if tab_start < 0 {
            tab_start = 0
        }
        let sp: Character = " "
        let preceded_by_spaces =
            region.start > 0 && (tab_start..<region.start).allSatisfy({ text.byte_at($0) == sp.asciiValue})
        if preceded_by_spaces && config.translate_tabs_to_spaces && config.use_tab_stops {
            return tab_start
        } else {
            enum State {
                case Start
                case Lf
                case BeforeKeycap
                case BeforeVsAndKeycap
                case BeforeEmojiModifier
                case BeforeVSAndEmojiModifier
                case BeforeVS
                case BeforeEmoji
                case BeforeZwj
                case BeforeVSAndZWJ
                case OddNumberedRIS
                case EvenNumberedRIS
                case InTagSequence
                case Finished
            };
            var state: State = .Start
            var tmp_offset = region.end

            var delete_code_point_count = 0
            var last_seen_vs_code_point_count = 0

            while state != .Finished && tmp_offset > 0 {
                var cursor = Cursor(text, tmp_offset)
                let code_point = cursor.prev_codepoint() ?? "0"

                tmp_offset = text.prev_codepoint_offset(tmp_offset) ?? 0

                switch state {
                case .Start:
                        delete_code_point_count = 1
                        if code_point == "\n" {
                            state = .Lf
                        } else if code_point.is_variation_selector() {
                            state = .BeforeVS
                        } else if code_point.is_regional_indicator_symbol() {
                            state = .OddNumberedRIS
                        } else if code_point.is_emoji_modifier() {
                            state = .BeforeEmojiModifier
                        } else if code_point.is_emoji_combining_enclosing_keycap() {
                            state = .BeforeKeycap
                        } else if code_point.is_emoji() {
                            state = .BeforeEmoji
                        } else if code_point.is_emoji_cancel_tag() {
                            state = .InTagSequence
                        } else {
                            state = .Finished;
                        }
                case .Lf:
                        if code_point == "\r" {
                            delete_code_point_count += 1
                        }
                        state = .Finished
                case .OddNumberedRIS:
                        if code_point.is_regional_indicator_symbol() {
                            delete_code_point_count += 1
                            state = .EvenNumberedRIS
                        } else {
                            state = .Finished
                        }
                case .EvenNumberedRIS:
                        if code_point.is_regional_indicator_symbol() {
                            delete_code_point_count -= 1
                            state = .OddNumberedRIS
                        } else {
                            state = .Finished
                        }
                case .BeforeKeycap:
                        if code_point.is_variation_selector() {
                            last_seen_vs_code_point_count = 1
                            state = .BeforeVsAndKeycap
                        } else {
                            if code_point.is_keycap_base() {
                                delete_code_point_count += 1
                            }
                            state = .Finished
                        }
                case .BeforeVsAndKeycap:
                    if code_point.is_keycap_base() {
                            delete_code_point_count += last_seen_vs_code_point_count + 1
                        }
                        state = .Finished
                case .BeforeEmojiModifier:
                        if code_point.is_variation_selector() {
                            last_seen_vs_code_point_count = 1
                            state = .BeforeVSAndEmojiModifier
                        } else {
                            if code_point.is_emoji_modifier_base() {
                                delete_code_point_count += 1
                            }
                            state = .Finished
                        }
                case .BeforeVSAndEmojiModifier:
                        if code_point.is_emoji_modifier_base() {
                            delete_code_point_count += last_seen_vs_code_point_count + 1
                        }
                        state = .Finished
                case .BeforeVS:
                        if code_point.is_emoji() {
                            delete_code_point_count += 1
                            state = .BeforeEmoji
                        } else {
                            if !code_point.is_variation_selector() {
                                //TODO: UCharacter.getCombiningClass(codePoint) == 0
                                delete_code_point_count += 1
                            }
                            state = .Finished
                        }
                case .BeforeEmoji:
                        if code_point.is_zwj() {
                            state = .BeforeZwj
                        } else {
                            state = .Finished
                        }
                case .BeforeZwj:
                        if code_point.is_emoji() {
                            delete_code_point_count += 2
                            state = code_point.is_emoji_modifier() ?
                                .BeforeEmojiModifier : .BeforeEmoji
                        } else if code_point.is_variation_selector() {
                            last_seen_vs_code_point_count = 1
                            state = .BeforeVSAndZWJ
                        } else {
                            state = .Finished
                        }
                case .BeforeVSAndZWJ:
                        if code_point.is_emoji() {
                            delete_code_point_count += last_seen_vs_code_point_count + 2
                            last_seen_vs_code_point_count = 0
                            state = .BeforeEmoji
                        } else {
                            state = .Finished
                        }
                case .InTagSequence:
                        if code_point.is_tag_spec_char() {
                            delete_code_point_count += 1
                        } else if code_point.is_emoji() {
                            delete_code_point_count += 1
                            state = .Finished
                        } else {
                            delete_code_point_count = 1
                            state = .Finished
                        }
                case .Finished:
                        break;
                }
            }

            var start = region.end
            while delete_code_point_count > 0 {
                start = text.prev_codepoint_offset(start) ?? 0
                delete_code_point_count -= 1
            }
            return start
        }
    }
}
