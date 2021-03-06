//
//  Tree.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 5/25/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
//  Its actually a direct translation of Rope from
//  https://github.com/xi-editor/xi-editor/blob/master/rust/rope/src/tree.rs
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

import IteratorTools

protocol NodeInfo: Codable, Hashable {
  associatedtype L: Leaf
  associatedtype DefaultMetric: Metric

  mutating func accumulate(other: inout Self)
  static func compute_info(leaf: inout L) -> Self
}

extension NodeInfo {
  static func identity() -> Self {
    var l = L.def()
    return compute_info(leaf: &l)
  }

  func interval(len: UInt) -> Interval {
    return Interval(0, len)
  }
}

struct NodeBody<N: NodeInfo>: Equatable, Codable, Hashable {
  var height: UInt
  var len: UInt
  var info: N
  var val: NodeVal<N>

  init(height: UInt, len: UInt, info: N, val: NodeVal<N>) {
    self.height = height
    self.len = len
    self.info = info
    self.val = val
  }

  static func == (lhs: NodeBody<N>, rhs: NodeBody<N>) -> Bool {
    return lhs.height == rhs.height && lhs.len == rhs.len && lhs.info == rhs.info
      && lhs.val == rhs.val
  }
}

struct PropertyKeyNode {
  static let height = "height"
  static let len = "len"
  static let info = "info"
  static let valLeaf = "valLeaf"
  static let valNodes = "valNodes"
}

class Node<N: NodeInfo>: Equatable, Codable, Hashable {
  var body: NodeBody<N>

  init(body: NodeBody<N>) {
    self.body = body
  }

  static func == (lhs: Node<N>, rhs: Node<N>) -> Bool {
    return lhs.body == rhs.body
  }

  static func from_leaf(l: inout N.L) -> Node<N> {
    let len = l.len()
    let info = N.compute_info(leaf: &l)
    return
      Node(
        body:
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
    switch body.val {
    case .Internal(var nodes):
      return f(&nodes)
    default:
      fatalError("get_children called on leaf node")
    }
  }

  func get_children_copy() -> [Node<N>] {
    switch body.val {
    case .Internal(let nodes):
      return nodes
    default:
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

  func get_leaf_copy() -> N.L {
    if case NodeVal.Leaf(let leaf) = body.val {
      return leaf
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
        let leaf2_iv = Interval(0, leaf2.len())
        let new = leaf1.push_maybe_split(other: &leaf2, iv: leaf2_iv)
        rope1.body.len = leaf1.len()
        rope1.body.info = N.compute_info(leaf: &leaf1)
        rope1.body.val = NodeVal.Leaf(leaf1)
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
      return rope2.get_children(f: { (rope2_children: inout [Node<N>]) -> Node<N> in
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
      })
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
        if h2 == h1 - 1 && rope2.is_ok_child() {
          return merge_nodes(children1: rope1_children, children2: [rope2])
        }
        let lastix = rope1_children.count - 1
        let newrope = concat(rope1: rope1_children[lastix], rope2: rope2)
        if newrope.height() == h1 - 1 {
          return merge_nodes(children1: Array(rope1_children[..<lastix]), children2: [newrope])
        }
        return newrope.get_children(f: { (newrope_children: inout [Node<N>]) -> Node<N> in
          return merge_nodes(
            children1: Array(rope1_children[..<lastix]), children2: newrope_children)
        })
      })
    } else {
      fatalError("should not happen")
    }
  }

  func subseq<T: IntervalBounds>(_ iv: T) -> Node<N> {
    let iv = iv.into_interval(upper_bound: self.len())
    var b = TreeBuilder<N>()
    self.push_subseq(b: &b, iv: iv)
    return b.build()
  }

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

  static func def() -> Node<N> {
    var def = N.L.def()
    return Node.from_leaf(l: &def)
  }

  func edit<T: Node<N>, IV: IntervalBounds>(_ iv: IV, _ new: T) -> Node<N> {
    var b = TreeBuilder<N>()
    let iv = iv.into_interval(upper_bound: self.len())
    let self_iv = self.interval()
    self.push_subseq(b: &b, iv: self_iv.prefix(iv))
    b.push(n: new)
    self.push_subseq(b: &b, iv: self_iv.suffix(iv))
    return b.build()
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(body)
  }
}

enum NodeVal<N: NodeInfo>: Codable, Equatable, Hashable {
  case Leaf(N.L)
  case Internal([Node<N>])
}

extension NodeVal {
  enum BadDataError: Error {
    case error
  }
  enum CodingKeys: String, CodingKey {
    case ifLeaf
    case ifNode
  }
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let ifLeaf = try container.decodeIfPresent(N.L.self, forKey: CodingKeys.ifLeaf)
    let ifNodes = try container.decodeIfPresent([Node<N>].self, forKey: CodingKeys.ifNode)
    if (ifLeaf == nil && ifNodes == nil) || (ifLeaf != nil && ifNodes != nil) {
      throw BadDataError.error
    }
    if ifLeaf != nil {
      self = .Leaf(ifLeaf!)
    } else {
      self = .Internal(ifNodes!)
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .Leaf(let leaf):
      try container.encode(leaf, forKey: CodingKeys.ifLeaf)
    case .Internal(let nodes):
      try container.encode(nodes, forKey: CodingKeys.ifNode)
    }
  }
}
struct MetricMeasurable<N: NodeInfo, M: Metric> {}
extension MetricMeasurable where N == M.N {
  static func measure(_ n: Node<N>) -> UInt {
    return M.measure(&n.body.info, n.len())
  }
}
struct NodeMeasurable2<M1: Metric, M2: Metric, N: NodeInfo> {
}
extension NodeMeasurable2 where M1.N == N, M2.N == N {
  // doesn't deal with endpoint, handle that specially if you need it
  static func convert_metrics(_ selv: Node<N>, _ mm1: UInt) -> UInt {
    var m1 = mm1
    if m1 == 0 {
      return 0
    }
    // If M1 can fragment, then we must land on the leaf containing
    // the m1 boundary. Otherwise, we can land on the beginning of
    // the leaf immediately following the M1 boundary, which may be
    // more efficient.
    let m1_fudge: UInt = M1.can_fragment() ? 1 : 0
    var m2: UInt = 0
    var node = selv
    while node.height() > 0 {
      for child in node.get_children_copy() {
        let child_m1 = MetricMeasurable<N, M1>.measure(child)
        if m1 < child_m1 + m1_fudge {
          node = child
          break
        }
        m2 += MetricMeasurable<N, M2>.measure(child)
        m1 -= child_m1
      }
    }
    var l = node.get_leaf_copy()
    let base = M1.to_base_units(&l, m1)
    return m2 + M2.from_base_units(&l, base)
  }
}
struct NodeMeasurable<N: NodeInfo, M: Metric> {
}
extension NodeMeasurable where N == M.N, N.DefaultMetric.N == N {
  static func count(_ selv: Node<N>, _ offset: UInt) -> UInt {
    return NodeMeasurable2<N.DefaultMetric, M, N>.convert_metrics(selv, offset)
  }
  static func count_base_units(_ selv: Node<N>, _ offset: UInt) -> UInt {
    return NodeMeasurable2<M, N.DefaultMetric, N>.convert_metrics(selv, offset)
  }
  static func measure(_ selv: Node<N>) -> UInt {
    return M.measure(&selv.body.info, selv.body.len)
  }
}

struct TreeBuilder<N: NodeInfo> {
  var node: Node<N>?
  init() {
    node = nil
  }

  mutating func push(n: Node<N>) {
    switch node {
    case .some(let buf):
      node = Optional.some(Node.concat(rope1: buf, rope2: n))
    default:
      node = Optional.some(n)
    }
  }

  mutating func push_leaves(leaves: [N.L]) {
    var stack = [[Node<N>]]()
    for var leaf in leaves {
      var new = Node<N>.from_leaf(l: &leaf)
      while true {
        if stack.last.map(_: { (r: [Node<N>]) -> Bool in
          r[0].height() != new.height()
        }) ?? true {
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
        new = Node.from_nodes(nodes: stack.removeLast())
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
  mutating func push_str(s: Substring) {
    //print("vvvvv push_str")
    if s.len() <= RopeConstants.MAX_LEAF {
      if !s.isEmpty {
        self.push_leaf(l: String(s))
      }
      return
    }
    var ss = s[...]
    while !ss.isEmpty {
      let splitpoint =
        ss.len() > RopeConstants.MAX_LEAF ? Utils.find_leaf_split_for_bulk(s: ss) : ss.len()
      let splitpoint_i: String.Index = String.Index(utf16Offset: Int(splitpoint), in: ss)
      let prefix = ss[..<splitpoint_i]
      self.push_leaf(l: String(prefix))
      ss.removeSubrange(..<splitpoint_i)
    }
  }

  mutating func push_str_stacked(s: inout String) {
    // print("vvvvv push_str_stacked")
    let leaves = Utils.split_as_leaves(s: s)
    self.push_leaves(leaves: leaves)
  }
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
  var cache = [(Node<N>, Int)?](repeatElement(nil, count: 4))
  /// The leaf containing the current position, when the cursor is valid.
  ///
  /// The position is only at the end of the leaf when it is at the end of the tree.
  var leaf: N.L?
  /// The offset of `leaf` within the tree.
  var offset_of_leaf: UInt

  init(_ n: Node<N>, _ position: UInt = 0) {
    self.root = n
    self.position = position
    self.leaf = .none
    self.offset_of_leaf = 0
    descend()
  }

  func get_leaf() -> (N.L, Int)? {
    return self.leaf.map({ (l: N.L) -> (N.L, Int) in
      return (l, Int(self.position - self.offset_of_leaf))
    })
  }

  func pos() -> UInt {
    return self.position
  }

  /// The length of the tree.
  func total_len() -> UInt { return self.root.len() }

  mutating func set_cache(elem: Node<N>, pos: Int, k: Int) {
    self.cache[k] = (elem, pos)
  }

  mutating func next_leaf() -> (N.L, Int)? {
    let leaf = self.leaf!
    self.position = self.offset_of_leaf + leaf.len()
    for i in 0..<Constants.CURSOR_CACHE_SIZE {
      if self.cache[i] == nil {
        // this probably can't happen
        self.leaf = .none
        return .none
      }
      let (node, j) = self.cache[i]!
      if j + 1 < node.get_children(f: { nodes -> UInt in return UInt(nodes.count) }) {
        self.cache[i] = .some((node, j + 1))
        let get_first_child: (inout [Node<N>]) -> Node<N> = { node_children -> Node<N> in
          return node_children[0]
        }
        let node_down = node.get_children(f: { node_children -> Node<N> in
          var node_down = node_children[Int(j) + 1]
          for k in (0..<i).reversed() {
            self.set_cache(elem: node_down, pos: 0, k: k)
            node_down = node_down.get_children(f: get_first_child)
          }
          return node_down
        })
        self.leaf = .some(node_down.get_leaf_copy())
        self.offset_of_leaf = self.position
        return self.get_leaf()
      }
    }
    if self.offset_of_leaf + self.leaf!.len() == self.root.len() {
      self.leaf = .none
      return .none
    }
    self.descend()
    return self.get_leaf()
  }

  mutating func descend() {
    var node = self.root
    var offset: UInt = 0
    while node.height() > 0 {
      node = node.get_children(f: { (children: inout [Node<N>]) -> Node<N> in
        var i = 0
        while true {
          if i + 1 == children.count {
            break
          }
          let nextoff = offset + children[i].len()
          if nextoff > self.position {
            break
          }
          offset = nextoff
          i += 1
        }
        let cache_ix = node.height() - 1
        if cache_ix < Constants.CURSOR_CACHE_SIZE {
          self.cache[Int(cache_ix)] = (node, i)
        }
        return children[i]
      })
    }
    self.leaf = .some(node.get_leaf_copy())
    self.offset_of_leaf = offset
  }

  /// Set the position of the cursor.
  ///
  /// The cursor is valid after this call.
  ///
  /// Precondition: `position` is less than or equal to the length of the tree.
  mutating func set(_ position: UInt) {
    self.position = position
    if let l = self.leaf {
      if self.position >= self.offset_of_leaf && self.position < self.offset_of_leaf + l.len() {
        return
      }
    }
    // TODO: walk up tree to find leaf if nearby
    self.descend()
  }

  /// Move to beginning of previous leaf.
  ///
  /// Return value: same as [`get_leaf`](#method.get_leaf).
  mutating func prev_leaf() -> (N.L, Int)? {
    if self.offset_of_leaf == 0 {
      self.leaf = nil
      self.position = 0
      return nil
    }
    for i in 0..<Constants.CURSOR_CACHE_SIZE {
      if self.cache[i] == nil {
        // this probably can't happen
        self.leaf = nil
        return nil
      }
      let (node, j) = self.cache[i]!
      if j > 0 {
        self.cache[i] = (node, j - 1)
        var node_down = node.get_children_copy()[j - 1]
        for k in (0..<i).reversed() {
          let last_ix = node_down.get_children_copy().count - 1
          self.cache[k] = (node_down, last_ix)
          node_down = node_down.get_children_copy()[last_ix]
        }
        let leaf = node_down.get_leaf_copy()
        self.leaf = leaf
        self.offset_of_leaf -= leaf.len()
        self.position = self.offset_of_leaf
        return self.get_leaf()
      }
    }
    self.position = self.offset_of_leaf - 1
    self.descend()
    self.position = self.offset_of_leaf
    return self.get_leaf()
  }
}

struct CursorMeasurable<N, M: Metric> where N == M.N, N.DefaultMetric.N == N {
  /// Tries to find the next boundary in the leaf the cursor is currently in.
  @inline(__always)
  static func next_inside_leaf(_ selv: inout Cursor<N>) -> UInt? {
    guard var l = selv.leaf else {
      fatalError("inconsistent, shouldn't get here")
    }
    let offset_in_leafp = selv.position - selv.offset_of_leaf
    let offset_in_leaf = M.next(&l, offset_in_leafp)!
    if offset_in_leaf == l.len() && selv.offset_of_leaf + offset_in_leaf != selv.root.len() {
      let _ = selv.next_leaf()
    } else {
      selv.position = selv.offset_of_leaf + offset_in_leaf
    }
    return selv.position
  }

  /// Moves the cursor to the next boundary.
  ///
  /// When there is no next boundary, returns `None` and the cursor becomes invalid.
  ///
  /// Return value: the position of the boundary, if it exists.
  static func next(_ selv: inout Cursor<N>) -> UInt? {
    if selv.position >= selv.root.len() || selv.leaf == nil {
      selv.leaf = nil
      return nil
    }

    if let offset = next_inside_leaf(&selv) {
      return offset
    }

    let _ = selv.next_leaf()
    if let offset = next_inside_leaf(&selv) {
      return offset
    }

    // Leaf is 0-measure (otherwise would have already succeeded).
    let measure = measure_leaf(&selv)
    descend_metric(&selv, measure + 1)
    if let offset = next_inside_leaf(&selv) {
      return offset
    }

    // Not found, properly invalidate cursor.
    selv.position = selv.root.len()
    selv.leaf = nil
    return nil
  }

  /// Returns the measure at the beginning of the leaf containing `pos`.
  ///
  /// This method is O(log n) no matter the current cursor state.
  static func measure_leaf(_ selv: inout Cursor<N>, _ pos: inout UInt) -> UInt {
    var node = selv.root
    var metric: UInt = 0
    while node.height() > 0 {
      for child in node.get_children_copy() {
        let len = child.len()
        if pos < len {
          node = child
          break
        }
        pos -= len
        metric += NodeMeasurable<N, M>.measure(child)
      }
    }
    return metric
  }

  /// Returns the measure at the beginning of the leaf containing `pos`.
  ///
  /// This method is O(log n) no matter the current cursor state.
  static func measure_leaf(_ selv: inout Cursor<N>) -> UInt {
    var pos = selv.position
    var node = selv.root
    var metric: UInt = 0
    while node.height() > 0 {
      for child in node.get_children_copy() {
        let len = child.len()
        if pos < len {
          node = child
          break
        }
        pos -= len
        metric += NodeMeasurable<N, M>.measure(child)
      }
    }
    return metric
  }

  /// Find the leaf having the given measure.
  ///
  /// This function sets `self.position` to the beginning of the leaf
  /// containing the smallest offset with the given metric, and also updates
  /// state as if [`descend`](#method.descend) was called.
  ///
  /// If `measure` is greater than the measure of the whole tree, then moves
  /// to the last node.
  static func descend_metric(_ selv: inout Cursor<N>, _ mmeasure: UInt) {
    var measure = mmeasure
    var node = selv.root
    var offset: UInt = 0
    while node.height() > 0 {
      let children = node.get_children_copy()
      var i = 0
      while true {
        if i + 1 == children.count {
          break
        }
        let child = children[i]
        let child_m = NodeMeasurable<N, M>.measure(child)
        if child_m >= measure {
          break
        }
        offset += child.len()
        measure -= child_m
        i += 1
      }
      let cache_ix = node.height() - 1
      if cache_ix < Constants.CURSOR_CACHE_SIZE {
        selv.cache[Int(cache_ix)] = (node, i)
      }
      node = children[i]
    }
    selv.leaf = node.get_leaf_copy()
    selv.position = offset
    selv.offset_of_leaf = offset
  }

  /// Returns the current position if it is a boundary in this [`Metric`],
  /// else behaves like [`prev`](#method.prev).
  ///
  /// [`Metric`]: struct.Metric.html
  static func at_or_prev(_ selv: inout Cursor<N>) -> UInt? {
    if CursorMeasurable<N, M>.is_boundary(&selv) {
      return selv.pos()
    } else {
      return prev(&selv)
    }
  }

  /// Determine whether the current position is a boundary.
  ///
  /// Note: the beginning and end of the tree may or may not be boundaries, depending on the
  /// metric. If the metric is not `can_fragment`, then they always are.
  static func is_boundary(_ selv: inout Cursor<N>) -> Bool {
    if selv.leaf == nil {
      // not at a valid position
      return false
    }
    if selv.position == selv.offset_of_leaf && !M.can_fragment() {
      return true
    }
    if selv.position == 0 || selv.position > selv.offset_of_leaf {
      return M.is_boundary(&selv.leaf!, selv.position - selv.offset_of_leaf)
    }
    // tricky case, at beginning of leaf, need to query end of previous
    // leaf; TODO: would be nice if we could do it another way that didn't
    // make the method &mut self.
    var l = selv.prev_leaf()!.0
    let result = M.is_boundary(&l, l.len())
    let _ = selv.next_leaf()
    return result
  }

  /// Moves the cursor to the previous boundary.
  ///
  /// When there is no previous boundary, returns `None` and the cursor becomes invalid.
  ///
  /// Return value: the position of the boundary, if it exists.
  static func prev(_ selv: inout Cursor<N>) -> UInt? {
    if selv.position == 0 || selv.leaf == nil {
      selv.leaf = nil
      return nil
    }
    let orig_pos = selv.position
    let offset_in_leaf = orig_pos - selv.offset_of_leaf
    if offset_in_leaf > 0 {
      var l = selv.leaf!
      if let offset_in_leaf = M.prev(&l, offset_in_leaf) {
        selv.position = selv.offset_of_leaf + offset_in_leaf
        return selv.position
      }
    }

    // not in same leaf, need to scan backwards
    let _ = selv.prev_leaf()!
    if let offset = last_inside_leaf(&selv, orig_pos) {
      return offset
    }

    // Not found in previous leaf, find using measurement.
    let measure = measure_leaf(&selv)
    if measure == 0 {
      selv.leaf = nil
      selv.position = 0
      return nil
    }
    descend_metric(&selv, measure)
    return last_inside_leaf(&selv, orig_pos)
  }

  static func last_inside_leaf(_ selv: inout Cursor<N>, _ orig_pos: UInt) -> UInt? {
    guard var l = selv.leaf else {
      fatalError("inconsistent, shouldn't get here")
    }
    let len = l.len()
    if selv.offset_of_leaf + len < orig_pos && M.is_boundary(&l, len) {
      let _ = selv.next_leaf()
      return selv.position
    }
    let offset_in_leaf = M.prev(&l, len)!
    selv.position = selv.offset_of_leaf + offset_in_leaf
    return selv.position
  }
}
