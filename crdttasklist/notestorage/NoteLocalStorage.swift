//
//  NoteLocalStorage.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-16.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

class NoteLocalStorage {

  static var savingQueue = DispatchQueue(label: "localFilesystem")

  static func justSaveNotes() {
    savingQueue.async {
      FileUtils.saveToFile(obj: Array(NoteStorage.shared._notes.values), url: Note.ArchiveURL)
    }
  }

  static func saveNotes() {
    savingQueue.async {
      justSaveNotes()
      NoteRemoteStorage.shared.conflictDetected()
    }
  }

  static func loadFrom(_ toUrl: URL, _ closure: @escaping ((Notes, Bool)?) -> Void) {
    savingQueue.async {
      guard let fileNotes = loadFromUrlInnerArray(toUrl) else {
        guard let dict = loadFromUrlInnerMap(toUrl) else {
          closure(nil)
          return
        }
        let wasMigrated = migrate(Array(dict.values))
        closure((dict, wasMigrated))
        return
      }
      let wasMigrated = migrate(fileNotes)
      let byId = Dictionary(grouping: fileNotes, by: { $0.id! }).mapValues { $0[0] }
      closure((byId, wasMigrated))
      return
    }
  }

  static func migrate(_ notes: [Note]) -> Bool {
    var wasMigrated = false
    //print("debugging lastModificationDate")
    for i in 0..<notes.count {
      let newV = notes[i].tryMigrate()
      wasMigrated = wasMigrated || newV
    }
    return wasMigrated
  }

  static func loadFromUrlInnerArray(_ toUrl: URL) -> [Note]? {
    return FileUtils.loadFromFile(type: [Note].self, url: toUrl)
  }
  static func loadFromUrlInnerMap(_ toUrl: URL) -> Notes? {
    return FileUtils.loadFromFile(type: Notes.self, url: toUrl)
  }
}
