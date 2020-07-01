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

  static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask)
    .first!
  static let ArchiveURL = DocumentsDirectory.appendingPathComponent("notes")
  static let TempArchiveURL = DocumentsDirectory.appendingPathComponent("temp-notes")

  var id: String?
  var crdt: CRDT
  var checklistCRDT: ChecklistCRDT?

  init(_ id: String, _ crdt: CRDT, _ checklistCRDT: ChecklistCRDT) {
    self.id = id
    self.crdt = crdt
    self.checklistCRDT = checklistCRDT
  }

  func update(_ crdt: CRDT) {
    self.crdt.merge(crdt)
    self.crdt.editing_finished()
  }

  func update(_ checklistCRDT: ChecklistCRDT) {
    self.checklistCRDT!.merge(checklistCRDT)
    self.checklistCRDT!.editing_finished()
    print("checklist \(self.checklistCRDT?.to_string() ?? "??")")
  }

  func merge(_ other: Note) -> (Note, CRDTMergeResult) {
    var res = crdt.merge(other.crdt)
    if let _ = checklistCRDT {
      if let _ = other.checklistCRDT {
        let mr = self.checklistCRDT!.merge(other.checklistCRDT!)
        res.merge(mr)
      } else {
        res.selfChanged = true
      }
    } else {
      if let ot = other.checklistCRDT {
        self.checklistCRDT = ot
        res.otherChanged = true
      }
    }
    return (self, res)
  }

  func dedupHash() -> Int {
    return crdt.to_string().hashValue &* 13 &+ id.hashValue
  }

  func getDisplayName() -> String {
    return crdt.to_string(25)
  }

  func creationDate() -> Date {
    return crdt.creationDate()
  }

  func modificationDate() -> Date {
    return Swift.max(crdt.modificationDate(), checklistCRDT!.modificationDate())
  }

  func isActive() -> Bool {
    return crdt.isActive()
  }

  func baseIntensity() -> Double {
    if isActive() {
      return 1
    } else {
      return 0.3
    }
  }

  func intensity1() -> Double {
    return checklistCRDT!.intensityDaily()
  }

  func intensity2() -> Double {
    return checklistCRDT!.intensityWeekly()
  }

  func markDeleted() {
    crdt.markDeleted()
  }

  func markUndeleted() {
    crdt.markUndeleted()
  }

  static func newNote() -> Note {
    let note = Note(IdGenerator.shared.generate(), CRDT(""), ChecklistCRDT())
    return note
  }

  func tryMigrate() -> Bool {
    var res = crdt.tryMigrate()
    if var checklistCRDT = checklistCRDT {
      if checklistCRDT.tryMigrate() {
        self.checklistCRDT = checklistCRDT
        res = true
      }
    } else {
      res = true
      checklistCRDT = ChecklistCRDT()
    }
    return res
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
  private(set) var value: Int = 0

  func generate() -> String {
    return
      "\(UIDevice.current.identifierForVendor!.uuidString)_\(NSDate().timeIntervalSince1970)_\(incrementAndGet())"
  }

  private func incrementAndGet() -> Int {
    return queue.sync {
      value += 1
      return value
    }
  }
}

extension Note: Storable {
  func commitEvents() -> [Event] {
    let crdtEvents = self.crdt.commitEvents() as! [CRDTEvent]
    let checklistCRDTEvents = self.checklistCRDT!.commitEvents() as! [ChecklistCRDTEvent]
    let noteEvent = NoteEvent(crdtEvents: crdtEvents, checklistCRDTEvents: checklistCRDTEvents)
    return [noteEvent]
  }
}
