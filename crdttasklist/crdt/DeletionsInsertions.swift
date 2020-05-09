//
//  DeletionsInsertions.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-09.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

enum DeletionsInsertionsType: Int, Codable {
    case Insert
    case Delete
}

struct DateAndType: Codable {
    let date: Date
    let type: DeletionsInsertionsType
}

struct DeletionsInsertions: Codable {
    var items: [DateAndType]

    init() {
        self.init(Date.init())
    }

    init(_ date: Date) {
        self.items = []
        self.items.append(DateAndType(date: date, type: .Insert))
    }

    func creationDate() -> Date {
        assert(items.first!.type == .Insert)
        return items.first!.date
    }

    func isActive() -> Bool {
        assert(items.first!.type == .Insert)
        return items.last!.type == .Insert
    }
}
