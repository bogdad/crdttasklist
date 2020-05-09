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

    func merge(_ other: Note) -> (Note, CRDTMergeResult) {
        let res = crdt.merge(other.crdt)
        return (self, res)
    }

    func dedupHash() -> Int {
        return crdt.to_string().hashValue &* 13 &+ id.hashValue
    }

    func getDisplayName() -> String {
        return crdt.to_string(30)
    }

    func creationDate() -> Date {
        return crdt.creationDate()
    }

    func modificationDate() -> Date {
        return crdt.modificationDate()
    }

    func isActive() -> Bool {
        return crdt.isActive()
    }

    func markDeleted() {
        crdt.markDeleted()
    }

    static func newNote() -> Note {
        let note = Note(IdGenerator.shared.generate(), CRDT(""))
        return note
    }

    func tryMigrate() -> Bool {
        return crdt.tryMigrate()
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
