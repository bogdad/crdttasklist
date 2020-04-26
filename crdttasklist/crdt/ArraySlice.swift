//
//  ArraySlice.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-03-25.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

extension ArraySlice {
    // returns slice with the first element and slice with the rest
    func split_first() -> (ArraySlice<Element>, ArraySlice<Element>)? {
        if count > 0 {
            if count > 1 {
                return (self[0...0], self[1...])
            }
            return (self[0...0], [])
        }
        return nil
    }

    // returns slice with the last element and slice with the all without last
    func split_last() -> (ArraySlice<Element>, ArraySlice<Element>)? {
        if count > 0 {
            if count > 1 {
                return (self.suffix(1), self.prefix(upTo: count - 2))
            } else {
                return (self.suffix(1), [])
            }
        }
        return nil
    }

    func len() -> Int {
        return count
    }
}
