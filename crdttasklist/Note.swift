//
//  Note.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-01-25.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import UIKit
import os.log

class Note: NSObject, NSCoding {
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("notes")

    var name: String
    var text: String

    required convenience init?(coder: NSCoder) {
        guard let name = coder.decodeObject(forKey: PropertyKey.name) as? String,
            let text = coder.decodeObject(forKey: PropertyKey.text) as? String
        else {
        return nil
        }
        self.init(name, text)
    }

    init(_ name: String, _ text: String) {
        self.name = name
        self.text = text
    }

    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: PropertyKey.name)
        coder.encode(text, forKey: PropertyKey.text)
    }
}

struct PropertyKey {
    static let name = "name"
    static let text = "text"
}
