//
//  Delta.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 5/25/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
//  Its actually a direct translation of Delta from
//  https://github.com/xi-editor/xi-editor/blob/master/rust/rope/src/delta.rs
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

enum DeltaElement<N: NodeInfo> {
    /// Represents a range of text in the base document. Includes beginning, excludes end.
    case Copy(UInt, UInt) // note: for now, we lose open/closed info at interval endpoints
    case Insert(Node<N>)
}

struct Delta<N: NodeInfo> {
    var els: [DeltaElement<N>]
    var base_len: UInt

    init(_ els: [DeltaElement<N>], _ base_len: UInt) {
        self.els = els
        self.base_len = base_len
    }

    static func simple_edit<T: IntervalBounds>(_ interval: T, _ rope: Node<N>, _ base_len: UInt) -> Delta<N> {
        var builder = DeltaBuilder<N>(base_len)
        if rope.is_empty() {
            builder.delete(interval)
        } else {
            builder.replace(interval, rope)
        }
        return builder.build()
    }

    /// Apply the delta to the given rope. May not work well if the length of the rope
    /// is not compatible with the construction of the delta.
    func apply(_ base: inout Node<N>) -> Node<N> {
        assert(base.len() == self.base_len, "must apply Delta to Node of correct length")
        var b = TreeBuilder<N>()
        for elem in self.els {
            switch elem {
            case .Copy(let tpl):
                base.push_subseq(b: &b, iv: Interval(tpl.0, tpl.1))
            case .Insert(let n):
                b.push(n: n.clone())
            }
        }
        return b.build()
    }

    /// Returns the length of the new document. In other words, the length of
    /// the transformed string after this Delta is applied.
    ///
    /// `d.apply(r).len() == d.new_document_len()`
    func new_document_len() -> UInt {
        return Delta.total_element_len(self.els)
    }

    static func total_element_len(_ els: [DeltaElement<N>]) -> UInt {
        return els.reduce(UInt(0), { (sum, el) in

            var add: UInt = 0
            switch el {
            case .Copy(let beg, let end):
                add = end - beg
            case .Insert(let n):
                add = n.len()
            }
            return sum + add
        })
    }

    // FIXME: what does it do?
    func factor() -> (InsertDelta<N>, Subset) {
        var ins = [DeltaElement<N>]()
        var sb = SubsetBuilder()
        var b1: UInt = 0
        var e1: UInt = 0
        for elem in self.els {
            switch elem {
            case DeltaElement.Copy(let b, let e):
                sb.add_range(e1, b, 1)
                e1 = e
            case DeltaElement.Insert(let n):
                if e1 > b1 {
                    ins.append(DeltaElement.Copy(b1, e1))
                }
                b1 = e1
                ins.append(DeltaElement.Insert(n))
            }
        }
        if b1 < self.base_len {
            ins.append(DeltaElement.Copy(b1, self.base_len));
        }
        sb.add_range(e1, self.base_len, 1)
        sb.pad_to_len(self.base_len);
        return (InsertDelta(elem: Delta(ins, self.base_len)), sb.build())
    }
}

struct InsertDelta<N: NodeInfo>{
    var elem: Delta<N>
}

struct DeltaBuilder<N: NodeInfo> {
    var delta: Delta<N>
    var last_offset: UInt

    init(_ base_len: UInt) {
        self.delta = Delta([], base_len)
        self.last_offset = 0
    }

    mutating func delete<T: IntervalBounds>(_ interval: T) {
        let interval = interval.into_interval(upper_bound: delta.base_len)
        let (start, end) = interval.start_end()
        assert(start >= self.last_offset, "Delta builder: intervals not properly sorted")
        if start > self.last_offset {
            self.delta.els.append(DeltaElement.Copy(self.last_offset, start))
        }
        self.last_offset = end
    }

    mutating func replace<T: IntervalBounds>(_ interval: T, _ rope: Node<N>) {
        self.delete(interval)
        if !rope.is_empty() {
            self.delta.els.append(DeltaElement.Insert(rope))
        }
    }

    mutating func build() -> Delta<N> {
        if self.last_offset < self.delta.base_len {
            self.delta.els.append(DeltaElement.Copy(self.last_offset, self.delta.base_len))
        }
        return self.delta
    }
}
