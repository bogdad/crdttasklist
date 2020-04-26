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
        return lhs.id == rhs.id && lhs.crdt == rhs.crdt
    }

    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("notes")
    static let TempArchiveURL = DocumentsDirectory.appendingPathComponent("temp-notes")

    var id: String?
    var crdt: CRDT

    init(_ id: String, _ crdt: CRDT) {
        self.id = id
        self.crdt = crdt
    }

    func update(_ crdt: CRDT) {
        self.crdt.merge(crdt)
        self.crdt.editing_finished()
    }

    func merge(_ other: Note) -> (Note, Bool) {
        return (self, false)
    }

    func dedupHash() -> Int {
        return crdt.to_string().hashValue * 13 + id.hashValue
    }

    func getDisplayName() -> String {
        return crdt.to_string(20)
    }

    static func newNote() -> Note {
        let note = Note(IdGenerator.shared.generate(), CRDT(""))
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
        return "\(UIDevice.current.identifierForVendor!.uuidString)_\(NSDate().timeIntervalSince1970)_\(incrementAndGet())"
    }

    private func incrementAndGet() -> Int {
        return queue.sync {
            value += 1
            return value
        }
    }
}
