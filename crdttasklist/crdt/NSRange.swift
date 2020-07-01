//
//  NSRange.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-04-25.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

extension NSRange {
  func to_interval() -> Interval {
    return Interval(UInt(lowerBound), UInt(upperBound))
  }

  static func from_interval(_ range: Interval) -> NSRange {
    return NSRange(location: Int(range.start), length: range.len())
  }
}
