//
//  Optional.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-16.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

extension Optional where Wrapped == CRDT {
  mutating func merge(_ other: Wrapped?) -> (CRDTMergeResult, Self) {
    switch self {
    case .none:
      switch other {
      case .none:
        return (CRDTMergeResult(selfChanged: false, otherChanged: false), self)
      case .some(let otherCrdt):
        self = otherCrdt
        return (CRDTMergeResult(selfChanged: true, otherChanged: false), self)
      }
    case .some(_):
      switch other {
      case .none:
        return (CRDTMergeResult(selfChanged: false, otherChanged: true), self)
      case .some(let otherCrdt):
        let (mergeResult, wrapped) = self!.merge(otherCrdt)
        self = wrapped
        return (mergeResult, wrapped)
      }

    }
  }
}

extension Optional where Wrapped == ChecklistCRDT {
  mutating func merge(_ other: Wrapped?) -> (CRDTMergeResult, Self) {
    switch self {
    case .none:
      switch other {
      case .none:
        return (CRDTMergeResult(selfChanged: false, otherChanged: false), self)
      case .some(let otherCrdt):
        self = otherCrdt
        return (CRDTMergeResult(selfChanged: true, otherChanged: false), self)
      }
    case .some(_):
      switch other {
      case .none:
        return (CRDTMergeResult(selfChanged: false, otherChanged: true), self)
      case .some(let otherCrdt):
        let (mergeResult, selv) = self!.merge(otherCrdt)
        return (mergeResult, selv)
      }

    }
  }
}
