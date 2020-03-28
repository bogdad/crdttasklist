//
//  String.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-03-28.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

extension String {

    func chars() -> [Int8] {
        var res = [Int8] (repeating: 0, count: count)
        self.withCString({ body in
            var i = 0
            while i < count {
                res[i] = body[i]
                i+=1
            }
        })
        return res
    }

    var lines: [String] {
        return self.components(separatedBy: "\n")
    }
}
