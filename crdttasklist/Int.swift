//
//  Int.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-23.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

extension Int {
    func pad_to(_ n: Int) -> String {
        let raw = "\(self)"
        return "0".repeate(n - raw.count) + raw
    }
}
