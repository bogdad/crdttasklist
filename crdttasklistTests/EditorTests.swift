//
//  EditorTests.swift
//  crdttasklistTests
//
//  Created by Vladimir Shakhov on 8/10/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//

import XCTest
import Foundation

@testable import crdttasklist

class EditorTests: XCTestCase {

    func test_plugin_edit() {
        let base_text: String = "hello"
        var editor = Editor(base_text)
        let rev = editor.get_head_rev_token()

        let view = View()

        editor.insert(view: &view, rope: Rope.from_str("ss"))

        XCTAssertEqual(editor.get_buffer().to_string(), "sshello")
    }
}
