//
//  EngineTests.swift
//  crdttasklistTests
//
//  Created by Vladimir Shakhov on 6/29/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
import XCTest

@testable import crdttasklist

class EngineTests: XCTestCase {

    let TEST_STR = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

    func build_delta_1() -> Delta<RopeInfo> {
        var d_builder = DeltaBuilder<RopeInfo>(TEST_STR.len())
        d_builder.delete(Interval(10, 36))
        d_builder.replace(Interval(39, 42), Rope.from_str("DEEF"[...]))
        d_builder.replace(Interval(54, 54), Rope.from_str("999"[...]))
        d_builder.delete(Interval(58, 61))
        return d_builder.build()
    }

    func test_edit_rev_simple() {
        var engine = Engine(Rope.from_str(TEST_STR[...]))
        let first_rev = engine.get_head_rev_id().token()
        engine.edit_rev(0, 1, first_rev, build_delta_1());
        XCTAssertEqual(("0123456789abcDEEFghijklmnopqr999stuvz", String.from(engine.get_head()))
    }

}
