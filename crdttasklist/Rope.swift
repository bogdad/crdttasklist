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
//
//
//
// Copyright 2016 The xi-editor Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import Foundation
import IteratorTools

struct Constants {
    static let MIN_CHILDREN = 4
    static let MAX_CHILDREN = 8
    static let CURSOR_CACHE_SIZE = 4;
}

struct RopeConstants {
    static let MIN_LEAF: UInt = 511;
    static let MAX_LEAF: UInt = 1024;
}

struct Interval: Equatable {
    var start: UInt
    var end: UInt
    init(start: UInt, end: UInt) {
        assert(start < end)
        self.start = start
        self.end = end
    }

    func is_empty() -> Bool {
        return end <= start
    }

    static func == (lhs: Interval, rhs: Interval) -> Bool {
        return lhs.start == rhs.start && lhs.end == rhs.end
    }

    func is_before(val: UInt) -> Bool {
        return end <= val
    }

    func intersect(other: Interval) -> Interval {
        let start = max(self.start, other.start)
        let end = min(self.end, other.end)
        return Interval(start: start, end: max(start, end))
    }

    func translate(amount: UInt) -> Interval {
        return Interval(start: start + amount, end: end + amount)
    }

    func translate_neg(amount: UInt) -> Interval {
        assert(start >= amount)
        return Interval(start: start - amount, end: end - amount)
    }

    func start_end() -> (UInt, UInt) {
        return (self.start, self.end)
    }
}

protocol Leaf : Equatable {
    static func def() -> Self
    func len() -> UInt
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

protocol NodeInfo: Equatable {
    associatedtype L: Leaf

    mutating func accumulate(other: inout Self)
    static func compute_info(leaf: inout L) -> Self
}

extension NodeInfo {
    static func identity() -> Self {
        var l = L.def()
        return compute_info(leaf: &l)
    }

    func interval(len: UInt) -> Interval {
        return Interval(start: 0, end: len)
    }
}

protocol DefaultMetric: NodeInfo {
    associatedtype DefaultMetric: Metric
}

struct NodeBody<N: NodeInfo> : Equatable {
    var height: UInt
    var len: UInt
    var info: N
    var val: NodeVal<N>

    init(height: UInt, len: UInt, info: N, val: NodeVal<N>) {
        self.height = height
        self.len = len
        self.info = info
        self.val = val
        //print("VOVAVO nodebody", val)
    }
}

class Node<N: NodeInfo> : Equatable {
    static func == (lhs: Node<N>, rhs: Node<N>) -> Bool {
        return lhs.body == rhs.body
    }

    var body: NodeBody<N>
    init(body: NodeBody<N>) {
        self.body = body
    }

    static func from_leaf(l: inout N.L) -> Node<N> {
        let len = l.len()
        let info = N.compute_info(leaf: &l)
        return
            Node(body:
                NodeBody(height: 0, len: len, info: info, val: NodeVal.Leaf(l)))
    }

    static func from_nodes(nodes: [Node<N>]) -> Node<N> {
        assert(nodes.count > 0)
        //print("VOVAVO from_nodes", nodes)
        let height = nodes[0].body.height + 1
        var len = nodes[0].body.len
        var info = nodes[0].body.info
        for child in nodes[1...] {
            len += child.body.len
            info.accumulate(other: &child.body.info)
        }
        return Node(body: NodeBody(height: height, len: len, info: info, val: NodeVal.Internal(nodes)))
    }

    func len() -> UInt {
        return body.len
    }

    func is_empty() -> Bool {
        return len() == 0
    }

    func height() -> UInt {
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
        let newOpt = rope2.get_leaf(f: { (leaf2: inout N.L) -> N.L? in
            if case NodeVal.Leaf(var leaf1) = rope1.body.val {
                let leaf2_iv = Interval(start: 0, end: leaf2.len())
                let new = leaf1.push_maybe_split(other: &leaf2, iv: leaf2_iv)
                rope1.body.len = leaf1.len()
                rope1.body.info = N.compute_info(leaf: &leaf1)
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

    static func concat(rope1: Node<N>, rope2: Node<N>) -> Node<N> {
        let h1 = rope1.height()
        let h2 = rope2.height()

        if h1 < h2 {
            let res = rope2.get_children(f: { (rope2_children: inout [Node<N>]) -> Node<N> in
                if h1 == h2 - 1 && rope1.is_ok_child() {
                    return merge_nodes(children1: [rope1], children2: rope2_children)
                }
                let newrope = concat(rope1: rope1, rope2: rope2_children[0])
                if newrope.height() == h2 - 1 {
                    return merge_nodes(children1: [newrope], children2: Array(rope2_children[1...]))
                } else {
                    return newrope.get_children(f: { (newrope_children: inout [Node<N>]) -> Node<N> in
                        return merge_nodes(children1: newrope_children, children2: Array(rope2_children[1...]))
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
                    return merge_nodes(children1: rope1_children, children2: rope2_children)
                })
            })
        } else if h1 > h2 {
            return rope1.get_children(f: { (rope1_children: inout [Node<N>]) -> Node<N> in
                // print("VOVAVO concat h1>h2", h1, h2)
                if h2 == h1 - 1 && rope2.is_ok_child() {
                    return merge_nodes(children1: rope1_children, children2: [rope2])
                }
                let lastix = rope1_children.count - 1
                let newrope = concat(rope1: rope1_children[lastix], rope2: rope2)
                if newrope.height() == h1 - 1 {
                    return merge_nodes(children1: Array(rope1_children[...lastix]), children2: [newrope])
                }
                return newrope.get_children(f: { (newrope_children: inout [Node<N>]) -> Node<N> in
                    return merge_nodes(children1: Array(rope1_children[...lastix]), children2: newrope_children)
                })
            })
        } else {
            fatalError("should not happen")
        }
    }

    // func measure<M: Metric>() -> UInt{
    //    return M.measure(body.info, len())
    // }

    func push_subseq(b: inout TreeBuilder<N>, iv: Interval) {
        if iv.is_empty() {
            return
        }
        if iv == interval() {
            b.push(n: clone())
            return
        }
        switch body.val {
        case .Leaf(var l):
            b.push_leaf_slice(l: &l, iv: iv)
        case .Internal(let v):
            var offset: UInt = 0
            for child in v {
                if iv.is_before(val: offset) {
                    break
                }
                let child_iv = child.interval()
                // easier just to use signed ints?
                let rec_iv = iv.intersect(other: child_iv.translate(amount: offset))
                    .translate_neg(amount: offset)
                child.push_subseq(b: &b, iv: rec_iv)
                offset += child.len()
            }
            return
        }
    }

    func clone() -> Node<N> {
        return Node(body: body)
    }
}

enum NodeVal<N: NodeInfo> : Equatable {
    case Leaf(N.L)
    case Internal([Node<N>])
}

protocol Metric {
    associatedtype N: NodeInfo
    static func measure(info: inout N, len: UInt) -> UInt
    static func to_base_units(l: inout N.L, in_measured_units: UInt) -> UInt
    static func from_base_units(l: inout N.L, in_base_units: UInt) -> UInt
    static func is_boundary(l: inout N.L, offset: UInt) -> Bool
    static func prev(l: inout N.L, offset: UInt) -> UInt?
    static func next(l: inout N.L, offset: UInt) -> UInt?
    static func can_fragment() -> Bool
}

struct TreeBuilder<N: NodeInfo> {
    var node: Node<N>?
    init() {
        node = nil
    }

    mutating func push(n: Node<N>) {
        switch node {
        case .some(let buf):
            //print("VOVAVO push buf node", buf.height(), Unmanaged.passUnretained(buf).toOpaque(), Unmanaged.passUnretained(n).toOpaque(), n.height())
            node = Optional.some(Node.concat(rope1: buf, rope2: n))
        default:
            //print("VOVAVO push node", n.height(), Unmanaged.passUnretained(n).toOpaque())
            node = Optional.some(n)
        }
    }

    mutating func push_leaves(leaves: [N.L]) {
        var stack = [[Node<N>]]()
        for var leaf in leaves {
            var new = Node<N>.from_leaf(l: &leaf)
            while true {
                if stack.last.map(_: { (r: [Node<N>]) -> Bool in
                    r[0].height() != new.height() }) ?? true {
                    stack.append([Node<N>]())
                }
                if stack.count > 0 {
                    stack[stack.count - 1].append(new)
                } else {
                    fatalError("should not happen")
                }
                if stack.last!.count < Constants.MAX_CHILDREN {
                    break
                }
                new = Node.from_nodes(nodes: stack.removeFirst())
            }
        }
        for v in stack {
            for r in v {
                push(n: r)
            }
        }
    }

    mutating func push_leaf_slice(l: inout N.L, iv: Interval) {
        var ll = l.subseq(iv: iv)
        push(n: Node.from_leaf(l: &ll))
    }


    mutating func push_leaf(l: N.L) {
        var leaf = l
        let n = Node<N>.from_leaf(l: &leaf)
        self.push(n: n)
    }


    func build() -> Node<N> {
        switch self.node {
        case .some(let r):
            return r
        case .none:
            var def = N.L.def()
            return Node.from_leaf(l: &def)
        }
    }
}

extension TreeBuilder where N == RopeInfo {
    /// Push a string on the accumulating tree in the naive way.
    ///
    /// Splits the provided string in chunks that fit in a leaf
    /// and pushes the leaves one by one onto the tree by calling.
    mutating func push_str(s: inout String) {
        if s.len() <= RopeConstants.MAX_LEAF {
            if !s.isEmpty {
                self.push_leaf(l: String(s))
            }
            return;
        }
        var ss = s[...]
        while !ss.isEmpty {
            //print("VOVAVO push_str ", ss)
            let splitpoint = ss.len() > RopeConstants.MAX_LEAF ? Utils.find_leaf_split_for_bulk(s: ss) : ss.len()
            let splitpoint_i: String.Index = String.Index(utf16Offset: Int(splitpoint), in: ss)
            let prefix = ss[..<splitpoint_i]
            self.push_leaf(l: String(prefix))
            // TODO: is it correct?
            ss.removeSubrange(..<splitpoint_i)
            //print("VOVAVO removing substring")
        }
    }

    mutating func push_str_stacked(s: inout String) {
        //print("VOVAVO push_str_stacked", s)
        let leaves = Utils.split_as_leaves(s: s)
        self.push_leaves(leaves: leaves)
    }
}



extension String: Leaf {
    static func def() -> String {
        return ""
    }

    func is_ok_child() -> Bool {
        return self.len() >= RopeConstants.MIN_LEAF
    }

    mutating func push_maybe_split(other: inout String, iv: Interval) -> String? {
        //print("VOVAVO push_maybe_split", other, iv);
        let (start, end) = iv.start_end()
        let s_i = String.Index(utf16Offset: Int(start), in: other)
        let e_i = String.Index(utf16Offset: Int(end), in: other)
        self.append(contentsOf: other[s_i..<e_i])
        if self.len() <= RopeConstants.MAX_LEAF {
            return Optional.none
        } else {
            let splitpoint = Utils.find_leaf_split_for_merge(s: self[...])
            let splitpoint_i = String.Index(utf16Offset: Int(splitpoint), in: self)
            let right_str = String(self[splitpoint_i...])
            self.removeSubrange(self.startIndex...splitpoint_i)
            //self.shrink_to_fit()
            return Optional.some(right_str)
        }
    }

    func len() -> UInt {
        return UInt(self.count)
    }

    func is_char_boundary(index: UInt) -> Bool {
        // 0 and len are always ok.
        // Test for 0 explicitly so that it can optimize out the check
        // easily and skip reading string data for that case.
        if index == 0 || index == self.len() {
            return true
        }
        if index > self.len() {
            return false
        }
        var res = true
        self.withCString {
            ( bytes : (UnsafePointer<CChar>) ) -> Void in
            res = bytes[Int(index)] >= -0x40
        }
        return res
    }

    static func from(rope: Rope) {
        r.slice_to_cow(..)
    }
}

extension Substring {
    func is_char_boundary(index: UInt) -> Bool {
        // 0 and len are always ok.
        // Test for 0 explicitly so that it can optimize out the check
        // easily and skip reading string data for that case.
        if index == 0 || index == self.len() {
            return true
        }
        if index > self.len() {
            return false
        }
        var res = true
        self.withCString {
            ( bytes : (UnsafePointer<CChar>) ) -> Void in
            res = bytes[Int(index)] >= -0x40
        }
        return res
    }

    func len() -> UInt {
        return UInt(self.count)
    }
}

struct RopeInfo: NodeInfo {
    typealias L = String

    var lines: UInt
    var utf16_size: UInt

    mutating func accumulate(other: inout RopeInfo) {
        self.lines += other.lines
        self.utf16_size += other.utf16_size
    }

    static func compute_info(leaf s: inout String) -> RopeInfo {
        return RopeInfo(
            lines: Utils.count_newlines(s: s[...]),
            utf16_size: Utils.count_utf16_code_units(s: &s))
    }
}

struct LinesMetric: Metric {
    static func measure(info: inout RopeInfo, len: UInt) -> UInt {
        return info.lines
    }

    static func to_base_units(l: inout String, in_measured_units: UInt) -> UInt {
        var offset:UInt = 0;
        for _ in 0...in_measured_units {
            let s_ind = String.Index(utf16Offset: Int(offset), in: l)
            let substr = l[s_ind...]
            let res = substr.firstIndex(of: "\n")
            switch res {
            case .some(let pos):
                offset += UInt(pos.utf16Offset(in: substr)) + 1
            default:
                fatalError("to_base_units called with arg too large")
            }
        }
        return offset
    }

    static func from_base_units(l: inout String, in_base_units: UInt) -> UInt {
        return Utils.count_newlines(s:l[...String.Index(utf16Offset: Int(in_base_units), in: l)])
    }

    static func is_boundary(l: inout String, offset: UInt) -> Bool {
        if offset == 0 {
            // shouldn't be called with this, but be defensive
            return false
        } else {
            return l[String.Index(utf16Offset: Int(offset - 1), in: l)] == "\n"
        }
    }

    static func prev(l: inout String, offset: UInt) -> UInt? {
        assert(offset > 0, "caller is responsible for validating input")
        let substr = l[...String.Index(utf16Offset: Int(offset), in: l)]
        return substr.firstIndex(of: "\n").map({ (pos:Substring.Index) -> UInt in
            return UInt(pos.utf16Offset(in: substr) + 1)
        })
    }

    static func next(l: inout String, offset: UInt) -> UInt? {
        let substr = l[String.Index(utf16Offset: Int(offset), in: l)...]
        return substr.firstIndex(of: "\n").map({ (pos:Substring.Index) -> UInt in
            return UInt(pos.utf16Offset(in: substr) + 1)
        })
    }

    static func can_fragment() -> Bool {
        return true
    }

    typealias N = RopeInfo

    // number of lines
    var val: UInt

    init() {
        val = 0
    }

}

protocol IntervalBounds {
    func into_interval(upper_bound:UInt) -> Interval
}

struct Cursor<N: NodeInfo> {
    /// The tree being traversed by this cursor.
    let root: Node<N>
    /// The current position of the cursor.
    ///
    /// It is always less than or equal to the tree length.
    var position: UInt
    /// The cache holds the tail of the path from the root to the current leaf.
    ///
    /// Each entry is a reference to the parent node and the index of the child. It
    /// is stored bottom-up; `cache[0]` is the parent of the leaf and the index of
    /// the leaf within that parent.
    ///
    /// The main motivation for this being a fixed-size array is to keep the cursor
    /// an allocation-free data structure.
    var cache = [(Node<N>, UInt)?](repeatElement(nil, count: 4))
    /// The leaf containing the current position, when the cursor is valid.
    ///
    /// The position is only at the end of the leaf when it is at the end of the tree.
    var leaf: N.L?
    /// The offset of `leaf` within the tree.
    var offset_of_leaf: UInt

    init(rope: Node<N>, start: UInt) {
        self.root = rope
        self.position = start
    }

    func get_leaf() -> (N.L, UInt)? {
        return self.leaf.map({ (l: N.L) -> (N.L, UInt) in
            return (l, self.position - self.offset_of_leaf)
        })
    }

    func pos() -> UInt {
        return self.position
    }

    mutating func next_leaf() -> (N.L, UInt)? {
        let leaf = self.leaf!
        self.position = self.offset_of_leaf + leaf.len()
        for i in 0...Constants.CURSOR_CACHE_SIZE {
            if self.cache[i] == nil {
                // this probably can't happen
                self.leaf = .none
                return .none
            }
    let (node, j) = self.cache[i].unwrap();
    if j + 1 < node.get_children().len() {
    self.cache[i] = Some((node, j + 1));
    let mut node_down = &node.get_children()[j + 1];
    for k in (0..i).rev() {
    self.cache[k] = Some((node_down, 0));
    node_down = &node_down.get_children()[0];
    }
    self.leaf = Some(node_down.get_leaf());
    self.offset_of_leaf = self.position;
    return self.get_leaf();
    }
    }
    if self.offset_of_leaf + self.leaf.unwrap().len() == self.root.len() {
    self.leaf = None;
    return None;
    }
    self.descend();
    self.get_leaf()
    }

}

struct ChunkIter: IteratorProtocol {
    typealias Element = RopeInfo

    let cursor: Cursor<RopeInfo>
    let end: UInt

    init(cursor: Cursor<RopeInfo>, end: UInt) {
        self.cursor = cursor
        self.end = end
    }

    mutating func next() -> RopeInfo? {
        if self.cursor.pos() >= self.end {
            return .none
        }
        let (leaf, start_pos) = self.cursor.get_leaf()!
        let len = min(self.end - self.cursor.pos(), leaf.len() - start_pos)
        self.cursor.next_leaf()
        return .some(leaf[start_pos...start_pos + len])
    }
}

typealias Rope = Node<RopeInfo>

extension Rope {

    func iter_chunks<T: IntervalBounds>(range: T) -> ChunkIter {
        let interval = range.into_interval(upper_bound: self.body.len)

        return ChunkIter(cursor: Cursor(rope: self, start: interval.start), end: interval.end)
    }

    func slice_to_cow<T: IntervalBounds>(range: T) -> String {
        var iter = self.iter_chunks(range: range)
    let first = iter.next();
    let second = iter.next();

    match (first, second) {
    (None, None) => Cow::from(""),
    (Some(s), None) => Cow::from(s),
    (Some(one), Some(two)) => {
    let mut result = [one, two].concat();
    for chunk in iter {
    result.push_str(chunk);
    }
    Cow::from(result)
    }
    (None, Some(_)) => unreachable!(),
    }
    }
}

struct Utils {

    static func count_newlines(s: Substring) -> UInt {
        let ns = s as NSString
        var count:UInt = 0
        ns.enumerateLines { (str, _) in
            count += 1
        }
        return count
    }

    static func count_utf16_code_units(s: inout String) -> UInt {
        var utf16_count: UInt = 0
        for b in s.utf16 {
            if Int8(b) >= -0x40 {
                utf16_count += 1
            }
            if Int16(b) >= 0xf0 {
                utf16_count += 1
            }
        }
        return utf16_count
    }

    static func find_leaf_split_for_merge(s: Substring) -> UInt {
        return find_leaf_split(s: s, minsplit: max(RopeConstants.MIN_LEAF, s.len() - RopeConstants.MAX_LEAF))
    }

    static func find_leaf_split_for_bulk(s: Substring) -> UInt {
        return find_leaf_split(s: s, minsplit: RopeConstants.MIN_LEAF)
    }

    static func find_leaf_split(s: Substring, minsplit: UInt) -> UInt {
        var splitpoint = min(RopeConstants.MAX_LEAF, s.len() - RopeConstants.MIN_LEAF)
        let s_ind = String.Index(utf16Offset: Int(minsplit - 1), in: s)
        let e_ind = String.Index(utf16Offset: Int(splitpoint), in: s)
        let substr = s[s_ind..<e_ind]
        let res = substr.firstIndex(of: "\n")
        switch res {
        case .some(let rng):
            // TODO: find out if utf16Offset is safe to be called on substr and not on substr.utf16
            return minsplit + UInt(rng.utf16Offset(in: substr))
        case .none:
            while !s.is_char_boundary(index: splitpoint) {
                splitpoint -= 1
            }
            return splitpoint
        }
    }

    static func split_as_leaves(s: String) -> [String] {
        var nodes = [String]()
        var ss = s[s.startIndex..<s.endIndex]
        while !ss.isEmpty {
            let splitpoint = ss.count > RopeConstants.MAX_LEAF ? Utils.find_leaf_split_for_bulk(s: ss) : ss.len()
            let splitpoint_i: String.Index = String.Index(utf16Offset: Int(splitpoint), in: ss)
            let prefix = ss[..<splitpoint_i]
            nodes.append(String(prefix))
            // TODO: is it correct?
            ss.removeSubrange(..<splitpoint_i)
        }
        return nodes
    }

}

