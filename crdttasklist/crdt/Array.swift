//
//  Array.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-03-08.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

extension Array where Element: Comparable & Equatable {


    struct IntError: Error {
        var i: Int
    }

    // https://github.com/rust-lang/rust/blob/a03921701cdfe0b2c5422240f3ae370ab21069f1/src/libcore/slice/mod.rs#L1539
    func binary_search(_ x: Element) -> (Int, Bool) // index, is_found
    {
        let s = self
        var size = s.count
        if size == 0 {
            return (0, false)
        }
        var base = 0
        while size > 1 {
            let half = size / 2
            let mid = base + half
            // mid is always in [0, size), that means mid is >= 0 and < size.
            // mid >= 0: by definition
            // mid < size: mid = size / 2 + size / 4 + size / 8 ...
            let cmp = x <= s[mid]
            if !cmp { // x is bigger that mid
                base = mid
            }
            size -= half
        }
        // base is always in [0, size) because base <= mid.
        if x == s[base] {
            return (base, true)
        } else if x < s[base] {
            return (base + 1, false)
        } else {
            return (base, false)
        }
    }
}
