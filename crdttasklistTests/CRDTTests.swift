//
//  CRDTTests.swift
//  crdttasklistTests
//
//  Created by Vladimir on 2020-05-03.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//
import XCTest

@testable import crdttasklist

class CRDTTests: XCTestCase {
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testIosSuggestReplace() {
        let crdt = CRDT("Hi rndown")
        let range = Interval(from: 3, length: 6)
        let str = "randown"
        crdt.replace(range, str)
        XCTAssertEqual("Hi randown", crdt.to_string())
    }

    func testReplaceWorks() {
        let crdt = CRDT("aBc")
        let range = Interval(from: 1, length: 1)
        let str = "12345"
        crdt.replace(range, str)
        XCTAssertEqual("a12345c", crdt.to_string())
    }

    func testInsertWorks() {
        let crdt = CRDT("")
        let range = Interval(from: 0, length: 0)
        let str = "1"
        crdt.replace(range, str)
        XCTAssertEqual("1", crdt.to_string())

        crdt.replace(Interval(1, 1), "2")
        XCTAssertEqual("12", crdt.to_string())
    }

    func testBackspaceWorks() {
        let crdt = CRDT("aBc")
        let range = Interval(from: 1, length: 1)
        let str = ""
        crdt.replace(range, str)
        XCTAssertEqual("ac", crdt.to_string())
    }
}
