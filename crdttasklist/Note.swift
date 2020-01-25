//
//  Note.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-01-25.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import UIKit

class Note {
// MARK: properties
    var name: String
    var text: String
//MARK: initialization
    init(_ name: String, _ text: String) {
        self.name = name
        self.text = text
    }
}
