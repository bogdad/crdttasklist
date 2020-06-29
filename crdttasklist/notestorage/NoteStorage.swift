//
//  NoteStorage.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-01-27.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

typealias Notes = [String: Note]

class NoteStorage {
    static let shared = NoteStorage()

    var _notes: Notes = [:]
    var rev: String?
    var currentNote: Note?

    func notes(_ filter: NoteTableFilter) -> [Note] {
        let n = orderNotes(Array(_notes.values))
        if filter == .active {
            return n.filter { $0.isActive() }
        } else {
            return n
        }
    }

    func orderNotes(_ notes: [Note]) -> [Note] {
        var checklist =
            notes
                .filter { $0.intensity1() > 0 || $0.intensity2() > 0}
                .sorted { $0.intensity1() * 100 + $0.intensity2() > $1.intensity1() * 100 + $1.intensity2()}

        let texts = notes.filter { $0.intensity1() == 0 && $0.intensity2() == 0}
                .sorted{ $0.modificationDate() > $1.modificationDate() }
        checklist.append(contentsOf: texts)
        return checklist
    }

    func editingFinished(_ crdt: CRDT) {
        if currentNote == nil {
            currentNote = Note.newNote()
        }
        currentNote?.update(crdt)
    }

    func editingFinished(_ crdt: ChecklistCRDT) {
        if currentNote == nil {
            currentNote = Note.newNote()
        }
        currentNote?.update(crdt)
    }

    func update() {
        NoteLocalStorage.saveNotes()
    }

    func update(_ note: inout Note) {
        _notes[note.id!] = note
        NoteLocalStorage.saveNotes()
    }

    func append(_ note: inout Note) {
        _notes[note.id!] = note
        NoteLocalStorage.saveNotes()
    }

    func markDeleted(_ note: Note) {
        note.markDeleted()
        NoteLocalStorage.saveNotes()
    }

    func markUndeleted(_ note: Note) {
        note.markUndeleted()
        NoteLocalStorage.saveNotes()
    }

    func loadNotes(_ closure: @escaping ((Notes, Bool)) -> Void) {
        NoteLocalStorage.loadFrom(try! Note.ArchiveURL.asURL(), {
            (res:(Notes, Bool)?) -> Void in
            guard let (notes, wasMigrated) = res else {
                self._notes = [:]
                NoteLocalStorage.saveNotes()
                closure((self._notes, false))
                return
            }
            self._notes = notes
            if wasMigrated {
                NoteLocalStorage.saveNotes()
            } else {
                NoteRemoteStorage.shared.conflictDetected()
            }
            closure((self._notes, wasMigrated))
        });
    }

    func mergeNotes(_ remoteNotes: Notes) -> (MergeStatus, Notes) {
        let localNotes = self._notes
        var localDict = localNotes
        let remoteDict = remoteNotes
        var numRemoteNewer = 0
        var numLocalNewer = 0
        localDict.merge(remoteDict, uniquingKeysWith: { (left, right) -> Note in
            let (newLocal, mergeResult) = left.merge(right)
            if mergeResult.otherChanged {
                print("mergeNotes: node \(left.id!) changed remotely")
                numRemoteNewer += 1
            }
            if mergeResult.selfChanged {
                print("mergeNotes: node \(left.id!) changed locally")
                numLocalNewer += 1
            }
            return newLocal
        })

        // TODO: handle deletions
        let newLocalNotes = localDict
        let numMissingLocally = newLocalNotes.count - localNotes.count
        let numMissingRemotely = newLocalNotes.count - remoteNotes.count
        print("mergeNotes: local count \(localNotes.count) remote count \(remoteNotes.count) new local count \(newLocalNotes.count)")
        print("mergeNotes: numMissingLocally \(numMissingLocally) numMissingRemotely \(numMissingRemotely)")
        print("mergeNotes: numLocalNewer \(numLocalNewer) numRemoteNewer \(numRemoteNewer) ")

        let needsUpload = numMissingRemotely > 0 || numLocalNewer > 0
        let needsLocalRedraw = numMissingLocally > 0 || numRemoteNewer > 0
        return (MergeStatus(needsUpload: needsUpload, needsLocalRedraw: needsLocalRedraw), newLocalNotes)
    }

    func notesChangedRemotely() {
        NotificationCenter.default.post(name: NSNotification.Name("notesChangedRemotely"), object: nil)
    }

    func checkRemotes() {
        NoteRemoteStorage.shared.checkRemotes()
    }

    func isStorageLinked() -> Bool {
        return NoteRemoteStorage.shared.isStorageLinked()
    }

    func eraseAllData() {
        self._notes = [:]
        do {
            try FileManager.default.removeItem(at: Note.ArchiveURL)
            try FileManager.default.removeItem(at: NoteRemoteStorage.MigrationsUrl1)
        } catch let error as NSError {
            print("Error: \(error.domain)")
        }
    }
}

struct MergeStatus {
    let needsUpload: Bool
    let needsLocalRedraw: Bool
}
