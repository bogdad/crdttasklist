//
//  File.swift
//  crdttasklistTests
//
//  Created by Vladimir Shakhov on 8/8/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
import XCTest
import Foundation

@testable import crdttasklist

class MultisetTests: XCTestCase {

    static var TEST_STR = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

    func transform_case(_ str1: String, _ str2: String, _ result: String) {
        let s1 = Cow(TestHelpers.find_deletions(str1, MultisetTests.TEST_STR))
        let s2 = Cow(TestHelpers.find_deletions(str2, str1))
        var s3 = s2.value.transform_expand(s1)
        let str3 = s3.delete_from_string(MultisetTests.TEST_STR)
        XCTAssertEqual(result, str3)
        XCTAssertEqual(str2, s1.value.transform_shrink(&s3).delete_from_string(str3))
        XCTAssertEqual(str2, s2.value.transform_union(s1).delete_from_string(MultisetTests.TEST_STR))
    }

    func testTransform() {
        transform_case(
            "02345678BCDFGHKLNOPQRTUVXZbcefghjlmnopqrstwx",
            "027CDGKLOTUbcegopqrw",
            "01279ACDEGIJKLMOSTUWYabcdegikopqruvwyz"
            )
        transform_case(
            "01234678DHIKLMNOPQRUWZbcdhjostvy",
            "136KLPQZvy",
            "13569ABCEFGJKLPQSTVXYZaefgiklmnpqruvwxyz"
            )
        transform_case(
            "0125789BDEFIJKLMNPVXabdjmrstuwy",
            "12BIJVXjmrstu",
            "12346ABCGHIJOQRSTUVWXYZcefghijklmnopqrstuvxz"
            )
        transform_case(
            "12456789ABCEFGJKLMNPQRSTUVXYadefghkrtwxz",
            "15ACEFGKLPRUVYdhrtx",
            "0135ACDEFGHIKLOPRUVWYZbcdhijlmnopqrstuvxy"
            )
        transform_case(
            "0128ABCDEFGIJMNOPQXYZabcfgijkloqruvy",
            "2CEFGMZabijloruvy",
            "2345679CEFGHKLMRSTUVWZabdehijlmnoprstuvwxyz"
            )
        transform_case(
            "01245689ABCDGJKLMPQSTWXYbcdfgjlmnosvy",
            "01245ABCDJLQSWXYgsv",
            "0123457ABCDEFHIJLNOQRSUVWXYZaeghikpqrstuvwxz"
            )
    }
}
