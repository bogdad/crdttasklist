//
//  Cow.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 7/21/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
// actual copyright https://gist.github.com/LucianoPAlmeida/e816b444834232506bad0078b4be0ad3
// and https://github.com/apple/swift/blob/master/docs/OptimizationTips.rst#advice-use-copy-on-write-semantics-for-large-values

import Foundation

final class Ref<T> {
    var val : T
    init(_ v : T) {val = v}
}

struct Cow<T> {
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
