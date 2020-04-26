//
//  RopeTests.swift
//  crdttasklistTests
//
//  Created by Vladimir Shakhov on 5/30/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//

import XCTest

@testable import crdttasklist

class RopeTests: XCTestCase {
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    func test_eq_node_from_leaf() {
        var s = build_triangle(n: 2_000)
        let node = Node<RopeInfo>.from_leaf(l: &s)
        XCTAssertEqual(node.height(), 0)
    }

    func testeq_rope_with_stack() {
        let n: UInt = 100
        var s = build_triangle(n: n)
        var builder_default = crdttasklist.TreeBuilder<RopeInfo>()
        var builder_stacked = crdttasklist.TreeBuilder<RopeInfo>()
        builder_default.push_str(s: s[...])
        builder_stacked.push_str_stacked(s: &s)
        let tree_default = builder_default.build()
        let tree_stacked = builder_stacked.build()
        // Stacked and Default produce different trees for now
        // And that is exactly how xi-editor rope eq is implemented
        XCTAssertEqual(tree_default.to_string(), tree_stacked.to_string())
    }

    func testNodeConcat() {
        var s1 = "abcdefghijk"
        var b1 = crdttasklist.TreeBuilder<RopeInfo>()
        b1.push_str(s: s1[...])
        let n1 = b1.build()

        var s2 = "12345"
        var b2 = crdttasklist.TreeBuilder<RopeInfo>()
        b2.push_str(s: s2[...])
        let n2 = b2.build()

        let n3 = Node.concat(rope1: n1, rope2: n2)

        XCTAssertTrue(n3.height() == 0)
        XCTAssertTrue(n2.height() == 0)
        XCTAssertTrue(n1.height() == 0)
    }

    func testtostrsmall() {
        var s = "12345678"
        var builder = crdttasklist.TreeBuilder<RopeInfo>()
        builder.push_str(s: s[...])
        let rope = builder.build()
        XCTAssertEqual(s, rope.to_string())
    }

    func testtostrbig() {
        var s = "123456781234567812345678"
        var builder = crdttasklist.TreeBuilder<RopeInfo>()
        builder.push_str(s: s[...])
        let rope = builder.build()
        //print(rope.to_string())
        XCTAssertEqual(s, rope.to_string())
    }

    func testverybig() {
        var s = build_triangle(n: 14)
        var builder = crdttasklist.TreeBuilder<RopeInfo>()
        builder.push_str(s: s[...])
        let rope = builder.build()
        //print(rope.to_string())
        XCTAssertEqual(s, rope.to_string())
    }

    func testveryverybig() {
        var s = build_triangle(n: 194)
        var builder = crdttasklist.TreeBuilder<RopeInfo>()
        builder.push_str(s: s[...])
        let rope = builder.build()
        //print(rope.to_string())
        XCTAssertEqual(s, rope.to_string())
    }

    func teststackedsmall() {
        var s = build_triangle(n: 100)
        var builder = crdttasklist.TreeBuilder<RopeInfo>()
        builder.push_str_stacked(s: &s)
        let rope = builder.build()
        XCTAssertEqual(s, rope.to_string())
    }

    func testeq_rope_with_stack_large() {
        let n: UInt = 400
        var s = build_triangle(n: n)
        var builder_default = crdttasklist.TreeBuilder<RopeInfo>()
        var builder_stacked = crdttasklist.TreeBuilder<RopeInfo>()
        builder_default.push_str(s: s[...])
        builder_stacked.push_str_stacked(s: &s)
        let tree_default = builder_default.build()
        let tree_stacked = builder_stacked.build()

        // to string works, but the trees are different!
        // it is exactly how xi-editor == works
        XCTAssertEqual(tree_default.to_string(), tree_stacked.to_string())
    }

    func testCodingDecoding() {
        let s = build_triangle(n: 100)
        let rope = Rope.from_str(s)
        let fileRope = saveThenLoad(obj: rope)
        XCTAssertEqual(rope.to_string(), fileRope.to_string())
    }

    func test_line_of_offset_small() {
        let a = Rope.from_str("a\nb\nc")
        XCTAssertEqual(0, a.line_of_offset(0))
        XCTAssertEqual(0, a.line_of_offset(1))
        XCTAssertEqual(1, a.line_of_offset(2))
        XCTAssertEqual(1, a.line_of_offset(3))
        XCTAssertEqual(2, a.line_of_offset(4))
        XCTAssertEqual(2, a.line_of_offset(5))
        let b = a.slice(Interval(2,4))
        XCTAssertEqual(0, b.line_of_offset(0))
        XCTAssertEqual(0, b.line_of_offset(1))
        XCTAssertEqual(1, b.line_of_offset(2))
    }

    func test_line_of_offset_small_1() {
        let a = Rope.from_str("a\nb\nc")
        let b = a.slice(Interval(2,4))
        XCTAssertEqual(1, b.line_of_offset(2))
    }

    func test_offset_of_line() {
        let rope = Rope.from_str("hi\ni'm\nfour\nlines")
        print(rope.len())
        XCTAssertEqual(rope.offset_of_line(0), 0)
        XCTAssertEqual(rope.offset_of_line(1), 3)
        XCTAssertEqual(rope.line_of_offset(0), 0)
        XCTAssertEqual(rope.line_of_offset(3), 1)
        // interior of first line should be first line
        XCTAssertEqual(rope.line_of_offset(1), 0)
        // interior of last line should be last line
        XCTAssertEqual(rope.line_of_offset(15), 3)
        XCTAssertEqual(rope.offset_of_line(4), rope.len())
    }

    func test_offset_of_line_1() {
        let rope = Rope.from_str("hi\ni'm\nfour\nlines")
        print(rope.len())
        // interior of last line should be last line
        XCTAssertEqual(rope.line_of_offset(3), 1)
    }

    func build_triangle(n: UInt) -> String {
        var s = String()
        var line = String()
        for i in 0...n {
            s += String(i)
            s += line
            s += "\n"
            line += "a"
        }
        return s
    }

}
