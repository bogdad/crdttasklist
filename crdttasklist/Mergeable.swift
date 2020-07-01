//
//  Mergeable.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-30.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

protocol Mergeable {
  mutating func merge(_ other: Self) -> CRDTMergeResult
}
