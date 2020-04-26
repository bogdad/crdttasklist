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
        let s1 = TestHelpers.find_deletions(str1, MultisetTests.TEST_STR)
        let s2 = TestHelpers.find_deletions(str2, str1)
        var s3 = s2.transform_expand(s1)
        let str3 = s3.delete_from_string(MultisetTests.TEST_STR)
        XCTAssertEqual(result, str3)
        XCTAssertEqual(str2, s1.transform_shrink(s3).delete_from_string(str3))
        XCTAssertEqual(str2, s2.transform_union(s1).delete_from_string(MultisetTests.TEST_STR))
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

    func test_apply() {
        var sb = SubsetBuilder()
        for (b, e) in [
            (0, 1),
            (2, 4),
            (6, 11),
            (13, 14),
            (15, 18),
            (19, 23),
            (24, 26),
            (31, 32),
            (33, 35),
            (36, 37),
            (40, 44),
            (45, 48),
            (49, 51),
            (52, 57),
            (58, 59),
        ] {
            sb.add_range(UInt(b), UInt(e), 1)
        }
        sb.pad_to_len(MultisetTests.TEST_STR.len())
        let s = sb.build()
        print("\(s)")
        XCTAssertEqual("145BCEINQRSTUWZbcdimpvxyz", s.delete_from_string(MultisetTests.TEST_STR))
    }

    func testtrivial() {
        let s = SubsetBuilder().build()
        XCTAssertTrue(s.is_empty())
    }

    func test_find_deletions() {
        let substr = "015ABDFHJOPQVYdfgloprsuvz"
        let s = TestHelpers.find_deletions(substr, MultisetTests.TEST_STR)
        XCTAssertEqual(substr, s.delete_from_string(MultisetTests.TEST_STR))
        XCTAssertTrue(!s.is_empty())
    }

    func test_complement() {
        let substr = "0456789DEFGHIJKLMNOPQRSTUVWXYZdefghijklmnopqrstuvw"
        let s = TestHelpers.find_deletions(substr, MultisetTests.TEST_STR)
        let c = s.complement()
        // deleting the complement of the deletions we found should yield the deletions
        XCTAssertEqual("123ABCabcxyz", c.delete_from_string(MultisetTests.TEST_STR))
    }

    func test_mapper() {
        let substr = "469ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwz"
        let s = TestHelpers.find_deletions(substr, MultisetTests.TEST_STR)
        var m = s.mapper(.NonZero)
        // subset is {0123 5 78 xy}
        XCTAssertEqual(0, m.doc_index_to_subset(0))
        XCTAssertEqual(2, m.doc_index_to_subset(2))
        XCTAssertEqual(2, m.doc_index_to_subset(2))
        XCTAssertEqual(3, m.doc_index_to_subset(3))
        XCTAssertEqual(4, m.doc_index_to_subset(4)) // not in subset
        XCTAssertEqual(4, m.doc_index_to_subset(5))
        XCTAssertEqual(5, m.doc_index_to_subset(7))
        XCTAssertEqual(6, m.doc_index_to_subset(8))
        XCTAssertEqual(6, m.doc_index_to_subset(8))
        XCTAssertEqual(8, m.doc_index_to_subset(60))
        XCTAssertEqual(9, m.doc_index_to_subset(61)) // not in subset
        XCTAssertEqual(9, m.doc_index_to_subset(62)) // not in subset
    }

    func test_union() {
        let s1 = TestHelpers.find_deletions("024AEGHJKNQTUWXYZabcfgikqrvy", MultisetTests.TEST_STR)
        var s2 = TestHelpers.find_deletions("14589DEFGIKMOPQRUXZabcdefglnpsuxyz", MultisetTests.TEST_STR)
        XCTAssertEqual("4EGKQUXZabcfgy", s1.union(s2).delete_from_string(MultisetTests.TEST_STR))
    }

}
