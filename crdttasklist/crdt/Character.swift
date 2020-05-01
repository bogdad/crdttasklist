//
//  Character.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-01.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation


extension Character {

    func is_variation_selector() -> Bool {
        let c = self
        return (c >= "\u{FE00}" && c <= "\u{FE0F}") || (c >= "\u{E0100}" && c <= "\u{E01EF}")
    }

    func is_regional_indicator_symbol() -> Bool {
        return self >= "\u{1F1E6}" && self <= "\u{1F1FF}"
    }

    func is_emoji_modifier() -> Bool {
        return self >= "\u{1F3FB}" && self <= "\u{1F3FF}"
    }

    func is_emoji_combining_enclosing_keycap() -> Bool {
        return self == "\u{20E3}"
    }

    func is_emoji() -> Bool {
        return Character.is_in_asc_list(self, EMOJI_TABLE, 0, EMOJI_TABLE.count - 1)
    }

    func is_emoji_cancel_tag() -> Bool {
        return self == "\u{E007F}"
    }

    func is_keycap_base() -> Bool {
        let c = self
        return ("0" <= c && c <= "9") || c == "#" || c == "*"
    }

    func is_zwj() -> Bool {
        return self == "\u{200D}"
    }

    func is_emoji_modifier_base() -> Bool {
        return Character.is_in_asc_list(self, EMOJI_MODIFIER_BASE_TABLE, 0, EMOJI_MODIFIER_BASE_TABLE.count - 1)
    }

    func is_tag_spec_char() -> Bool {
        return "\u{E0020}" <= self && self <= "\u{E007E}"
    }

    static func is_in_asc_list<T: Comparable>(_ c: T, _ list: [T], _ start: Int, _ end: Int) -> Bool {
        if c == list[start] || c == list[end] {
            return true;
        }
        if end - start <= 1 {
            return false;
        }

        let mid = (start + end) / 2;

        if c >= list[mid] {
            return is_in_asc_list(c, list, mid, end)
        }
        return is_in_asc_list(c, list, start, mid)
    }
}
