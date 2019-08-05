//
//  DeltaTests.swift
//  crdttasklistTests
//
//  Created by Vladimir Shakhov on 6/29/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
import XCTest

@testable import crdttasklist

extension Delta where N==RopeInfo {
    func apply_to_string(_ s: String) -> String {
        var incoming_rope = Rope.from_str(s[...])
        let rope = self.apply(incoming_rope)
        return String.from(rope: rope)
    }
}

extension InsertDelta where N==RopeInfo {
    func apply_to_string(_ s: String) -> String {
        var incoming_rope = Rope.from_str(s[...])
        let rope = self.apply(incoming_rope)
        return String.from(rope: rope)
    }
}

class DeltaTests: XCTestCase {

    func testSimple() {
        let d = Delta.simple_edit(Interval(1, 9), Rope.from_str("era"), 11)
        XCTAssertEqual("herald", d.apply_to_string("hello world"))
        XCTAssertEqual(6, d.new_document_len())
    }

    func testFactor() {
        let d = Delta.simple_edit(Interval(1, 9), Rope.from_str("era"), 11)
        let (d1, ss) = d.factor()
        XCTAssertEqual("heraello world", d1.apply_to_string("hello world"))
        XCTAssertEqual("hld", ss.delete_from_string("hello world"))
    }

    func testSynthesize() {
        let d = Delta.simple_edit(Interval(1, 9), Rope.from_str("era"), 11)
        var (d1, del) = d.factor()
        var ins = Cow(d1.inserted_subset())
        del = del.transform_expand(ins)
        var union_str = d1.apply_to_string("hello world")
        print("union_str", union_str)
        let tombstones = ins.value.complement().delete_from_string(&union_str)
        print("tombstones", tombstones)
        let new_d = Delta.synthesize(Rope.from_str(tombstones[...]), &ins.value, &del)
        assert("herald" == new_d.apply_to_string("hello world"))
        let text = del.complement().delete_from_string(&union_str)
        print("text", text)
        let inv_d = Delta.synthesize(Rope.from_str(text[...]), &del, &ins.value)
        assert("hello world" == inv_d.apply_to_string("herald"))
    }

}
