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

    func eq_rope_with_stack() {
        let n: UInt = 2_000
        let s = build_triangle(n:n)
        var builder_default = crdttasklist.TreeBuilder()
        var builder_stacked = crdttasklist.TreeBuilder()
        builder_default.push_str(&s)
        builder_stacked.push_str_stacked(&s)
        let tree_default = builder_default.build()
        let tree_stacked = builder_stacked.build()
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
