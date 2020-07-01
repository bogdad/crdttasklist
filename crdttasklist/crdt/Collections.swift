//
//  Collections.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 8/1/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
// Actually copied from
// https://stackoverflow.com/questions/25329186/safe-bounds-checked-array-lookup-in-swift-through-optional-bindings

import Foundation

extension Collection {

  /// Returns the element at the specified index if it is within bounds, otherwise nil.
  subscript(safe index: Index) -> Element? {
    return indices.contains(index) ? self[index] : nil
  }
}
