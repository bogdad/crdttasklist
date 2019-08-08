//
//  TestHelpers.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 8/8/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//

import Foundation

class TestHelpers {
    /// Creates a `Subset` of `s` by scanning through `substr` and finding which
    /// characters of `s` are missing from it in order. Returns a `Subset` which
    /// when deleted from `s` yields `substr`.
    static func find_deletions(_ substr: String, _ s: String) -> Subset {
        var sb = SubsetBuilder()
        var j: UInt = 0
        for i: UInt in 0...UInt(s.count) {
            if j < substr.count {
                let substr_j = substr.index(substr.startIndex, offsetBy: Int(j))
                let s_i = s.index(s.startIndex, offsetBy: Int(i))
                if substr[substr_j] == s[s_i] {
                    j += 1;
                } else {
                    sb.add_range(i, i + 1, 1)
                }
            } else {
                sb.add_range(i, i + 1, 1)
            }
        }
        sb.pad_to_len(s.len());
        return sb.build()
    }
}
