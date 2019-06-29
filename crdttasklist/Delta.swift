//
//  Rope.swift
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
        var builder = Builder<N>(base_len)
        if rope.is_empty() {
            builder.delete(interval)
        } else {
            builder.replace(interval, rope)
        }
        return builder.build()
    }

}

struct InsertDelta<N: NodeInfo>{
    var elem: Delta<N>
}

struct Builder<N: NodeInfo> {
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
