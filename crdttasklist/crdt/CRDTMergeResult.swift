//
//  CRDTMergeResult.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-09.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

struct CRDTMergeResult {
    let selfChanged: Bool
    let otherChanged: Bool
}
