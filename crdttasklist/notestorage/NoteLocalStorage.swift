//
//  NoteLocalStorage.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-16.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
class NoteLocalStorage {

    static func justSaveNotes() {
        FileUtils.saveToFile(obj: Array(NoteStorage.shared._notes.values), url: Note.ArchiveURL)
    }

    static func saveNotes() {
        justSaveNotes()
        NoteRemoteStorage.shared.conflictDetected()
    }

    static func loadFrom(_ toUrl: URL) -> (Notes, Bool)? {
        guard let fileNotes = loadFromUrlInnerArray(toUrl) else {
            guard let dict = loadFromUrlInnerMap(toUrl) else {
                return nil
            }
            let wasMigrated = migrate(Array(dict.values))
            return (dict, wasMigrated)
        }
        let wasMigrated = migrate(fileNotes)
        let byId = Dictionary(grouping: fileNotes, by: { $0.id!} ).mapValues { $0[0] }
        return (byId, wasMigrated)
    }

    static func migrate(_ notes: [Note]) -> Bool {
        var wasMigrated = false
        //print("debugging lastModificationDate")
        for note in notes.sorted(by: { $0.modificationDate() > $1.modificationDate() } ) {
            //print("note \(note.id!) modified \(note.modificationDate())")
        }
        for note in notes {
            let newV = note.tryMigrate()
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
