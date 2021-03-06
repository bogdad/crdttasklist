//
//  Iterator.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-03-14.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

extension IteratorProtocol {
  mutating func nth(_ n: Int) -> Element? {
    var i = 0
    var res: Element? = nil
    while i <= n {
      res = next()
      i -= 1
    }
    return res
  }
}
