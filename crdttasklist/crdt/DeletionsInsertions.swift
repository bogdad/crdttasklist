//
//  DeletionsInsertions.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-09.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import BTree

enum DeletionsInsertionsType: Int, Codable, Equatable {
    case Insert
    case Delete
}

struct DeletionsInsertions: Codable, Equatable {
    static func == (lhs: DeletionsInsertions, rhs: DeletionsInsertions) -> Bool {
        return lhs.items == rhs.items
    }

    typealias DeletionsInsertionsMap = BTree<Date, DeletionsInsertionsType>

    var items:DeletionsInsertionsMap

    init() {
        self.init(Date.init())
    }

    init(_ date: Date) {
        self.items = BTree()
        self.items.insert((date, DeletionsInsertionsType.Insert))
    }

    func creationDate() -> Date {
        assert(items.first!.1 == .Insert)
        return items.first!.0
    }

    func isActive() -> Bool {
        assert(items.first!.1 == .Insert)
        return items.last!.1 == .Insert
    }

    func lastCreatedDate() -> Date? {
        if items.last!.1 == .Insert {
            return items.last!.0
        }
        return nil
    }

    func modificationDate() -> Date {
        return items.last!.0
    }

    mutating func markCreated() {
        self.items.insert((Date(), .Insert))
    }

    mutating func markDeleted() {
        self.items.insert((Date(), .Delete))
    }

    mutating func merge(_ other: DeletionsInsertions) -> CRDTMergeResult {
        var selfChanged = false
        var otherChanged = false
        for left in items {
            let oItem = other.items.value(of: left.0)
            if  oItem == nil {
                selfChanged = true
            } else {
                if oItem! != left.1 {
                    selfChanged = true
                    otherChanged = true
                }
            }
        }
        for right in other.items {
            let lItem = items.value(of: right.0)
            if lItem == nil {
                otherChanged = true
            } else {
                if lItem! != right.1 {
                    selfChanged = true
                    otherChanged = true
                }
            }
        }
        items = items.union(other.items, by: .groupingMatches)
        return CRDTMergeResult(selfChanged: selfChanged, otherChanged: otherChanged)
    }
}
