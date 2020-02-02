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
    static let TempArchiveURL = DocumentsDirectory.appendingPathComponent("temp-notes")

    var id: String?
    var name: String
    var text: String
    var textEditor: Editor

    required convenience init?(coder: NSCoder) {
        guard let name = coder.decodeObject(forKey: PropertyKey.name) as? String,
            let text = coder.decodeObject(forKey: PropertyKey.text) as? String
        else {
        return nil
        }
        let id = coder.decodeObject(forKey: PropertyKey.id) as? String
        let textEditor = coder.decodeObject(forKey: PropertyKey.editor) as? Editor
        self.init(id ?? IdGenerator.shared.generate(), name, text, textEditor ?? Editor(text))
    }

    init(_ id: String, _ name: String, _ text: String, _ textEditor: Editor) {
        self.id = id
        self.name = name
        self.text = text
        self.textEditor = textEditor
    }

    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: PropertyKey.id)
        coder.encode(name, forKey: PropertyKey.name)
        coder.encode(text, forKey: PropertyKey.text)
        coder.encode(textEditor, forKey: PropertyKey.editor)
    }

    func update(_ name: String, _ text: String) {
        self.name = name
        self.text = text
    }

    func merge(_ other: Note) -> (Note, Bool) {
        var changed = false
        if name != other.name {
            name += other.name
            changed = true
        }
        if text != other.text {
            text += other.text
            changed = true
        }
        return (self, changed)
    }

    func dedupHash() -> Int {
        name.hashValue &* 13 &+ text.hashValue
    }

    static func newNote(name: String = "name?", text: String = "text?") -> Note {
        let note = Note(IdGenerator.shared.generate(), name, text, Editor(text))
        return note
    }
}

extension Sequence where Element == Note {
    func sortedById() -> [Note] {
        return self.sorted(by: { $0.id! < $1.id! })
    }
}

class IdGenerator {

    static var shared = IdGenerator()
    private var queue = DispatchQueue(label: "IdGenerator")
    private (set) var value: Int = 0

    func generate() -> String {
        "\(UIDevice.current.identifierForVendor!.uuidString)_\(NSDate().timeIntervalSince1970)_\(incrementAndGet())"
    }

    private func incrementAndGet() -> Int {
        queue.sync {
            value += 1
            return value
        }
    }
}

struct PropertyKey {
    static let id = "id"
    static let name = "name"
    static let text = "text"
    static let editor = "editor"
}
