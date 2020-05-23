//
//  ChecklistCrdt.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-16.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

struct ChecklistCRDT: Codable {

    var lastModificationDate: Date
    var storage: CRDT

    init() {
        lastModificationDate = Date()
        storage = CRDT("")
    }

    mutating func merge(_ other: ChecklistCRDT) -> CRDTMergeResult {
        return CRDTMergeResult(selfChanged: false, otherChanged: false)
    }

    func modificationDate() -> Date {
        return lastModificationDate
    }

    mutating func tryMigrate() -> Bool {
        return false
    }
}
