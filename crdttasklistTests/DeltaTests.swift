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

    let TEST_STR = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

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
        var ins = d1.inserted_subset()
        del = del.transform_expand(ins)
        var union_str = d1.apply_to_string("hello world")
        print("union_str", union_str)
        let tombstones = ins.complement().delete_from_string(union_str)
        print("tombstones", tombstones)
        let new_d = Delta.synthesize(Rope.from_str(tombstones[...]), ins, del)
        XCTAssertTrue("herald" == new_d.apply_to_string("hello world"))
        let text = del.complement().delete_from_string(&union_str)
        print("text", text)
        let inv_d = Delta.synthesize(Rope.from_str(text[...]), del, ins)
        XCTAssertTrue("hello world" == inv_d.apply_to_string("herald"))
    }

    func test_transform_expand() {
        let str1 = "01259DGJKNQTUVWXYcdefghkmopqrstvwxy"
        let s1 = TestHelpers.find_deletions(str1, TEST_STR)
        let d = Delta<RopeInfo>.simple_edit(Interval(10, 12), Rope.from_str("+"), str1.len())
        assert("01259DGJKN+UVWXYcdefghkmopqrstvwxy" == d.apply_to_string(str1))
        let (d2, _ss) = d.factor()
        XCTAssertEqual("01259DGJKN+QTUVWXYcdefghkmopqrstvwxy", d2.apply_to_string(str1))
        let d3 = d2.transform_expand(s1, false)
        XCTAssertEqual(
            "0123456789ABCDEFGHIJKLMN+OPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz",
            d3.apply_to_string(TEST_STR)
        )
        let d4 = d2.transform_expand(s1, true)
        XCTAssertEqual(
            "0123456789ABCDEFGHIJKLMNOP+QRSTUVWXYZabcdefghijklmnopqrstuvwxyz",
            d4.apply_to_string(TEST_STR)
        )
    }

    func test_transform_expand_simple() {
        let str1 = "first"
        let str1andstuff = "andfiondrstsec"
        let s1 = TestHelpers.find_deletions(str1, str1andstuff)
        let d = Delta<RopeInfo>.simple_edit(Interval(1, 4), Rope.from_str("+"), str1.len())
        XCTAssertEqual("f+t", d.apply_to_string(str1))
        let (d2, _) = d.factor()
        XCTAssertEqual("f+irst", d2.apply_to_string(str1))
        let d3 = d2.transform_expand(s1, false)
        XCTAssertEqual(
            "andf+iondrstsec",
            d3.apply_to_string(str1andstuff)
        )
        let d4 = d2.transform_expand(s1, true)
        XCTAssertEqual(
            "andf+iondrstsec",
            d4.apply_to_string(str1andstuff)
        )
    }

    func test_inserted_subset() {
        let d = Delta.simple_edit(Interval(1, 9), Rope.from_str("era"), 11)
        let (d1, _) = d.factor()
        XCTAssertEqual("hello world", d1.inserted_subset().delete_from_string("heraello world"))
    }

    
}
