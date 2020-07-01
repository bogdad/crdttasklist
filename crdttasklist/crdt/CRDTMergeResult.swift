//
//  CRDTMergeResult.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-09.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

struct CRDTMergeResult {
  var selfChanged: Bool
  var otherChanged: Bool
  mutating func merge(_ other: CRDTMergeResult) {
    selfChanged = selfChanged || other.selfChanged
    otherChanged = otherChanged || other.otherChanged
  }
}
