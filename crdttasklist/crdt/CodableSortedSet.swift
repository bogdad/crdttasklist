//
//  CodableSortedSet.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-02-08.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import BTree

class CodableSortedSet<T: Comparable&Codable>: Codable {
    var set: SortedSet<T>

    convenience init() {
        self.init(SortedSet())
    }

    init(_ set: SortedSet<T>) {
        self.set = set
    }

    enum CodingKeys: String, CodingKey {
        case set
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Array(set), forKey: .set)
    }

    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let arr = try container.decode(Array<T>.self, forKey: .set)
        self.init(SortedSet(arr))
    }
}
