//
//  Rope.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 5/25/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
//  Its actually a direct translation of Rope from
//  https://github.com/xi-editor/xi-editor/blob/master/rust/rope/src/rope.rs
//  to Swift

import Foundation
import IteratorTools

struct Constants {
    static let MIN_CHILDREN = 4
    static let MAX_CHILDREN = 8
}

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
        if is_good == nil {
            fatalError("unexpected split")
        }
        return result
    }
}

protocol NodeInfo {
    associatedtype L: Leaf

    mutating func accumulate(other: inout Self)
    static func compute_info(leaf: inout L) -> Self
}

extension NodeInfo {
    static func identity() -> Self {
        var l = L.def()
        return compute_info(leaf: &l)
    }

    func interval(len: Int) -> Interval {
        return Interval(start: 0, end: len)
    }
}

struct NodeBody<N: NodeInfo> {
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

class Node<N: NodeInfo> {
    typealias NL = N.L
    var body: NodeBody<N>
    init(body: NodeBody<N>) {
        self.body = body
    }

    static func from_leaf(l: inout NL) -> Node<N> {
        let len = l.len()
        let info = N.compute_info(leaf: &l)
        return
            Node(body:
                NodeBody(height: 0, len: len, info: info, val: NodeVal.Leaf(l)))
    }

    static func from_nodes(nodes: [Node<N>]) -> Node<N> {
        assert(nodes.count > 0)
        let height = nodes[0].body.height + 1
        var len = nodes[0].body.len
        var info = nodes[0].body.info
        for child in nodes[1...] {
            len += child.body.len
            info.accumulate(other: &child.body.info)
        }
        return Node(body: NodeBody(height: height, len: len, info: info, val: NodeVal.Internal(nodes)))
    }

    func len() -> Int {
        return body.len
    }

    func is_empty() -> Bool {
        return len() == 0
    }

    func height() -> Int {
        return body.height
    }

    func is_leaf() -> Bool {
        return body.height == 0
    }

    func interval() -> Interval {
        return body.info.interval(len: len())
    }

    func get_children<R>(f: (inout [Node<N>]) -> R) -> R {
        if case var NodeVal.Internal(nodes) = body.val {
            return f(&nodes)
        } else {
            fatalError("get_children called on leaf node")
        }
    }

    func get_leaf<R>(f: (inout N.L) -> R) -> R {
        if case var NodeVal.Leaf(leaf) = body.val {
            return f(&leaf)
        } else {
            fatalError("get_leaf called on internal node")
        }
    }

    func is_ok_child() -> Bool {
        switch body.val {
        case let NodeVal.Leaf(leaf):
            return leaf.is_ok_child()
        case let NodeVal.Internal(nodes):
            return nodes.count >= Constants.MIN_CHILDREN
        }
    }

    static func merge_nodes(children1: [Node<N>], children2: [Node<N>]) -> Node<N> {
        let n_children = children1.count + children2.count
        if n_children <= Constants.MAX_CHILDREN {
            return from_nodes(nodes: children1 + children2)
        } else {
            // Note: this leans left. Splitting at midpoint is also an option
            let splitpoint = min(Constants.MAX_CHILDREN, n_children - Constants.MIN_CHILDREN)
            let chain_iterator = chain(children1, children2)

            // TODO: there must be a lot of copying going on below
            let left = Array(chain_iterator.prefix(splitpoint))
            let right = Array(chain_iterator.dropFirst(splitpoint))

            let parent_nodes = [from_nodes(nodes: left), from_nodes(nodes: right)]
            return from_nodes(nodes: parent_nodes)
        }
    }

    static func merge_leaves(rope1: Node<N>, rope2: Node<N>) -> Node<N> {
        assert(rope1.is_leaf() && rope2.is_leaf())

        let both_ok = rope1.is_ok_child() && rope2.is_ok_child()
        if both_ok {
            return from_nodes(nodes: [rope1, rope2])
        }
        var node1 = rope1.body
        let newOpt = rope2.get_leaf(f: { (leaf2: inout N.L) -> N.L? in
            if case var NodeVal.Leaf(leaf1) = node1.val {
                let leaf2_iv = Interval(start: 0, end: leaf2.len())
                let new = leaf1.push_maybe_split(other: &leaf2, iv: leaf2_iv)
                node1.len = leaf1.len()
                node1.info = N.compute_info(leaf: &leaf1)
                return new
            } else {
                fatalError("merge_leaves called on non-leaf")
            }
        })
        switch newOpt {
        case var .some(new):
            return from_nodes(nodes: [rope1, from_leaf(l: &new)])
        default:
            return rope1
        }
    }

    static func concat(rope1: inout Node<N>, rope2: Node<N>) -> Node<N> {
        let h1 = rope1.height()
        let h2 = rope2.height()

        if h1 < h2 {
            let res = rope2.get_children(f: { (rope2_children: inout [Node<N>]) -> Node<N> in
                if h1 == h2 - 1 && rope1.is_ok_child() {
                    return merge_nodes(children1: [rope1], children2: rope2_children)
                }
                let newrope = concat(rope1: &rope1, rope2: rope2_children[0])
                if newrope.height() == h2 - 1 {
                    return merge_nodes(children1: [newrope], children2: Array(rope2_children[1...]))
                } else {
                    return newrope.get_children(f: { (newrope_children: inout [Node<N>]) -> Node<N> in
                        merge_nodes(children1: newrope_children, children2: Array(rope2_children[1...]))
                    })
                }
            }
            )
            return res
        } else if h1 == h2 {
            if rope1.is_ok_child() && rope2.is_ok_child() {
                return from_nodes(nodes: [rope1, rope2])
            }
            if h1 == 0 {
                return merge_leaves(rope1: rope1, rope2: rope2)
            }
            return rope1.get_children(f: { (rope1_children: inout [Node<N>]) -> Node<N> in
                rope2.get_children(f: { (rope2_children: inout [Node<N>]) -> Node<N> in
                    merge_nodes(children1: rope1_children, children2: rope2_children)
                })
            })
        } else if h1 > h2 {
            return rope1.get_children(f: { (rope1_children: inout [Node<N>]) -> Node<N> in
                if h2 == h1 - 1 && rope2.is_ok_child() {
                    return merge_nodes(children1: rope1_children, children2: [rope2])
                }
                let lastix = rope1_children.count - 1
                let newrope = concat(rope1: &rope1_children[lastix], rope2: rope2)
                if newrope.height() == h1 - 1 {
                    return merge_nodes(children1: Array(rope1_children[...lastix]), children2: [newrope])
                }
                return newrope.get_children(f: { (newrope_children: inout [Node<N>]) -> Node<N> in
                    merge_nodes(children1: Array(rope1_children[...lastix]), children2: newrope_children)
                })
            })
        } else {
            fatalError("should not happen")
        }
    }
}

enum NodeVal<N: NodeInfo> {
    case Leaf(N.L)
    case Internal([Node<N>])
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
