//
//  NoteTests.swift
//  crdttasklistTests
//
//  Created by Vladimir on 2020-02-08.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import XCTest
@testable import crdttasklist

class NoteTests: XCTestCase {
    func testCodingDecoding() {
        let note = Note("1234", "name", "text", Editor("text"))
        let fileNote = saveThenLoad(obj: note)

        XCTAssertEqual(note, fileNote)
    }
}
