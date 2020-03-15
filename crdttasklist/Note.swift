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

class Note: Codable, Equatable {
    static func == (lhs: Note, rhs: Note) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name && lhs.text == rhs.text && lhs.crdt == rhs.crdt
    }

    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("notes")
    static let TempArchiveURL = DocumentsDirectory.appendingPathComponent("temp-notes")

    var id: String?
    var name: String
    var text: String
    var crdt: CRDT

    init(_ id: String, _ name: String, _ text: String, _ crdt: CRDT) {
        self.id = id
        self.name = name
        self.text = text
        self.crdt = crdt
    }

    func update(_ name: String, _ crdt: CRDT) {
        self.name = name
        self.crdt = crdt
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
        let note = Note(IdGenerator.shared.generate(), name, text, CRDT(text))
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
