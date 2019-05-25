//
//  Rope.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 5/25/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//

import Foundation

class Rope {

}

struct Interval {
    var start: Int
    var end: Int
    init(start: Int, end: Int) {
        assert(start < end)
        self.start = start
        self.end = end
    }
}

protocol Leaf {
    static func def() -> Self
    func len() -> Int
    func is_ok_child() -> Bool
    mutating func push_maybe_split(other: inout Self, iv: Interval) -> Self?
}

extension Leaf {
    mutating func subseq(iv: Interval) -> Self {
        var result = type(of: self).def()
        let is_good = result.push_maybe_split(other: &self, iv: iv)
        if (is_good == nil) {
            fatalError("unexpected split")
        }
        return result
    }
}

protocol NodeInfo {
    associatedtype L: Leaf

    func accumulate(other: inout Self)
    func compute_info(leaf: inout L) -> Self
}

extension NodeInfo {
    func identity() -> Self {
        var l = L.def()
        return compute_info(leaf: &l)
    }
    func interval(len: Int) -> Interval {
        return Interval(start: 0, end: len)
    }
}

class NodeBody<N: NodeInfo> {
    var height: Int
    var len: Int
    var info: N
    var val: NodeVal<N>

    init(height: Int, len: Int, info: N, val: NodeVal<N>) {
        self.height = height
        self.len = len
        self.info = info
        self.val = val
    }
}


enum NodeVal<N: NodeInfo> {
    typealias L = N.L
    case Leaf(L)
    case Internal([NodeBody<N>])
}

protocol Metric {
    associatedtype N: NodeInfo
    typealias NL = N.L
    static func measure(info: inout N, len: Int) -> Int
    static func to_base_units(l: inout NL, in_measured_units: Int) -> Int
    static func from_base_units(l: inout NL, in_base_units: Int) -> Int
    static func is_boundary(l: inout NL, offset: Int) -> Bool
    static func prev(l: inout NL, offset: Int) -> Int?
    static func next(l: inout NL, offset: Int) -> Int?
    static func can_fragment() -> Bool
}
