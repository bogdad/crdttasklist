//
//  NoteLocalStorage.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-16.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
class NoteLocalStorage {
    static func loadFrom(_ toUrl: URL) -> (Notes, Bool)? {
        guard let fileNotes = loadFromUrlInnerArray(toUrl) else {
            guard var dict = loadFromUrlInnerMap(toUrl) else {
                return nil
            }
            var wasMigrated = false
            print("debugging lastModificationDate")
            for note in dict.values.sorted(by: { $0.modificationDate() > $1.modificationDate() } ) {
                print("note \(note.id!) modified \(note.modificationDate())")
            }
            for note in dict.values {
                let newV = note.tryMigrate()
                wasMigrated = wasMigrated || newV
                dict[note.id!] = note
            }
            return (dict, wasMigrated)
        }
        var wasMigrated = false
        var migrated: [Note] = []
        print("debugging lastModificationDate")
        for note in fileNotes.sorted(by: { $0.modificationDate() > $1.modificationDate() } ) {
            print("note \(note.id!) modified \(note.modificationDate())")
        }
        for n in fileNotes {
            let newW = n.tryMigrate()
            wasMigrated = wasMigrated || newW
            migrated.append(n)
        }
        let byId = Dictionary(grouping: migrated, by: { $0.id!} ).mapValues { $0[0] }
        return (byId, wasMigrated)
    }


    static func loadFromUrlInnerArray(_ toUrl: URL) -> [Note]? {
        return FileUtils.loadFromFile(type: [Note].self, url: toUrl)
    }
    static func loadFromUrlInnerMap(_ toUrl: URL) -> Notes? {
        return FileUtils.loadFromFile(type: Notes.self, url: toUrl)
    }
}
