//
//  Cow.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 7/21/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
// actual copyright https://gist.github.com/LucianoPAlmeida/e816b444834232506bad0078b4be0ad3
// and https://github.com/apple/swift/blob/master/docs/OptimizationTips.rst#advice-use-copy-on-write-semantics-for-large-values

import Foundation
import BTree

final class Ref<T: Codable&Equatable>: Codable, Equatable {
    static func == (lhs: Ref<T>, rhs: Ref<T>) -> Bool {
        return lhs.val == rhs.val
    }

    var val : T
    init(_ v : T) {val = v}
}

struct Cow<T: Codable&Equatable>: Codable, Equatable {
    var ref : Ref<T>
    init(_ x : T) { ref = Ref(x) }

    var value: T {
        get { return ref.val }
        set {
            if (!isKnownUniquelyReferenced(&ref)) {
                ref = Ref(newValue)
                return
            }
            ref.val = newValue
        }
    }
}

final class RefRaw<T: Equatable>: Equatable {
    static func == (lhs: RefRaw<T>, rhs: RefRaw<T>) -> Bool {
        return lhs.val == rhs.val
    }

    var val : T
    init(_ v : T) {val = v}
}

struct CowSortedSet<T: Codable & Comparable>: Codable, Equatable {
    var ref : RefRaw<SortedSet<T>>

    init() {
        ref = RefRaw(SortedSet())
    }
    init(_ x : SortedSet<T>) { ref = RefRaw(x) }

    var value: SortedSet<T> {
        get { return ref.val }
        set {
            if (!isKnownUniquelyReferenced(&ref)) {
                ref = RefRaw(newValue)
                return
            }
            ref.val = newValue
        }
    }

    enum CodingKeys: String, CodingKey {
        case set
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Array(ref.val), forKey: .set)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let arr = try container.decode(Array<T>.self, forKey: .set)
        self.init(SortedSet(arr))
    }

}


