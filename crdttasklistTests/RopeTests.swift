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
        builder_default.push_str(s: &s)
        builder_stacked.push_str_stacked(s: &s)
        let tree_default = builder_default.build()
        let tree_stacked = builder_stacked.build()
        XCTAssertEqual(tree_default, tree_stacked)
    }

    func testNodeConcat() {
        var s1 = "abcdefghijk"
        var b1 = crdttasklist.TreeBuilder<RopeInfo>()
        b1.push_str(s: &s1)
        let n1 = b1.build()

        var s2 = "12345"
        var b2 = crdttasklist.TreeBuilder<RopeInfo>()
        b2.push_str(s: &s2)
        let n2 = b2.build()

        let n3 = Node.concat(rope1: n1, rope2: n2)

        XCTAssertTrue(n3.height() == 0)
        XCTAssertTrue(n2.height() == 0)
        XCTAssertTrue(n1.height() == 0)
    }

    func testtostrsmall() {
        var s = "12345678"
        var builder = crdttasklist.TreeBuilder<RopeInfo>()
        builder.push_str(s: &s)
        let rope = builder.build()
        XCTAssertEqual(s, rope.to_string())
    }

    func testtostrbig() {
        var s = "123456781234567812345678"
        var builder = crdttasklist.TreeBuilder<RopeInfo>()
        builder.push_str(s: &s)
        let rope = builder.build()
        XCTAssertEqual(s, rope.to_string())
    }

    func testeq_rope_with_stack_large() {
        let n: UInt = 200
        var s = build_triangle(n: n)
        var builder_default = crdttasklist.TreeBuilder<RopeInfo>()
        var builder_stacked = crdttasklist.TreeBuilder<RopeInfo>()
        builder_default.push_str(s: &s)
        builder_stacked.push_str_stacked(s: &s)
        let tree_default = builder_default.build()
        let tree_stacked = builder_stacked.build()
        print("default ", tree_default.to_string())
        print("stacked ", tree_stacked.to_string())
        XCTAssertEqual(tree_default, tree_stacked)
    }

    func build_triangle(n: UInt) -> String {
        var s = String()
        var line = String()
        for _ in 0...n {
            s += line
            s += "\n"
            line += "a"
        }
        return s
    }

}
