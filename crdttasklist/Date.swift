//
//  Date.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-30.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

extension Date : Mergeable {
    mutating func merge(_ other: Date) -> CRDTMergeResult {
        var res = CRDTMergeResult(selfChanged: false, otherChanged: false)
        let max = Swift.max(self, other)
        if self != max {
            res.otherChanged = true
        }
        if other != max {
            res.selfChanged = true
        }
        self = max
        return res
    }
}

extension Date: Storable {
    mutating func commitEvents() -> [Event] {
        return [DateEvent(date: self)]
    }
}
