//
//  Optional.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-16.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

extension Optional where Wrapped == CRDT {
  mutating func merge(_ other: Wrapped?) -> CRDTMergeResult {
    switch self {
    case .none:
      switch other {
      case .none:
        return CRDTMergeResult(selfChanged: false, otherChanged: false)
      case .some(let otherCrdt):
        self = otherCrdt
        return CRDTMergeResult(selfChanged: true, otherChanged: false)
      }
    case .some(_):
      switch other {
      case .none:
        return CRDTMergeResult(selfChanged: false, otherChanged: true)
      case .some(let otherCrdt):
        return self!.merge(otherCrdt)
      }

    }
  }
}

extension Optional where Wrapped == ChecklistCRDT {
  mutating func merge(_ other: Wrapped?) -> CRDTMergeResult {
    switch self {
    case .none:
      switch other {
      case .none:
        return CRDTMergeResult(selfChanged: false, otherChanged: false)
      case .some(let otherCrdt):
        self! = otherCrdt
        return CRDTMergeResult(selfChanged: true, otherChanged: false)
      }
    case .some(_):
      switch other {
      case .none:
        return CRDTMergeResult(selfChanged: false, otherChanged: true)
      case .some(let otherCrdt):
        return self!.merge(otherCrdt)
      }

    }
  }
}
