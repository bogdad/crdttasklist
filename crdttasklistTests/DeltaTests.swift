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

class DeltaTests: XCTestCase {

    func testSimple() {
        let d = Delta.simple_edit(Interval(1, 9), Rope.from_str("era"), 11)
        XCTAssertEqual("herald", d.apply_to_string("hello world"))
        XCTAssertEqual(6, d.new_document_len())
    }

}
