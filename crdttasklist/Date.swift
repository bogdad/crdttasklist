//
//  Date.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-30.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

extension Date: Mergeable {
  mutating func merge(_ other: Date) -> (CRDTMergeResult, Self) {
    var res = CRDTMergeResult(selfChanged: false, otherChanged: false)
    let max = Swift.max(self, other)
    if self != max {
      res.otherChanged = true
    }
    if other != max {
      res.selfChanged = true
    }
    self = max
    return (res, self)
  }
}

extension Date: Storable {
  mutating func commitEvents(_ appState: AppState) -> [Event] {
    return [DateEvent(date: self)]
  }
}
