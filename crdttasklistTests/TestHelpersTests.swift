//
//  TestHelpersTests.swift
//  crdttasklistTests
//
//  Created by Vladimir Shakhov on 8/10/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
import XCTest
import Foundation

@testable import crdttasklist

class TestHelpersTests: XCTestCase {
    func testFindDeletions() {
        let s = "abcd"
        let subs = "bc"
        let deletions = TestHelpers.find_deletions(subs, s)
        let left = deletions.delete_from_string(s)
        let deleted = deletions.complement().delete_from_string(s)

        XCTAssertEqual("bc", left)
        XCTAssertEqual("ad", deleted)
    }
}
