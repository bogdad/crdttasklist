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

    func notes() -> [Note] {
        return Array(_notes.values).filter { $0.isActive() } .sorted{ $0.creationDate() < $1.creationDate() }
    }

    func noteByIndexPath(_ row: NSInteger) -> Note {
        return self.notes()[row]
    }

    func editingFinished(_ crdt: CRDT) {
        if currentNote == nil {
            currentNote = Note.newNote()
        }
        currentNote?.update(crdt)
    }

    func update(_ note: inout Note) {
        _notes[note.id!] = note
        saveNotes()
    }

    func append(_ note: inout Note) {
        _notes[note.id!] = note
        saveNotes()
    }

    func markDeleted(_ row: NSInteger) {
        noteByIndexPath(row).markDeleted()
        saveNotes()
    }

    func getNotes() -> [Note] {
        return notes()
    }

    func loadNotes() -> Bool {
        guard let (notes, wasMigrated) = loadFrom(try! Note.ArchiveURL.asURL()) else {
            self._notes = [:]
            saveNotes()
            NoteRemoteStorage.shared.conflictDetected()
            return false
        }
        self._notes = notes
        if wasMigrated {
            saveNotes()
        }
        NoteRemoteStorage.shared.conflictDetected()

        return true
    }

    func saveNotes() {
        FileUtils.saveToFile(obj: Array(self._notes.values), url: Note.ArchiveURL)
        NoteRemoteStorage.shared.conflictDetected()
    }

    func loadFromUrlInnerArray(_ toUrl: URL) -> [Note]? {
        return FileUtils.loadFromFile(type: [Note].self, url: toUrl)
    }
    func loadFromUrlInnerMap(_ toUrl: URL) -> Notes? {
        return FileUtils.loadFromFile(type: Notes.self, url: toUrl)
    }

    func loadFrom(_ toUrl: URL) -> (Notes, Bool)? {
        guard let fileNotes = loadFromUrlInnerArray(toUrl) else {
            guard var dict = loadFromUrlInnerMap(toUrl) else {
                return nil
            }
            var wasMigrated = false
            for note in dict.values {
                let newV = note.tryMigrate()
                wasMigrated = wasMigrated || newV
                dict[note.id!] = note
            }
            return (dict, wasMigrated)
        }
        var wasMigrated = false
        var migrated: [Note] = []
        for n in fileNotes {
            let newW = n.tryMigrate()
            wasMigrated = wasMigrated || newW
            migrated.append(n)
        }
        let byId = Dictionary(grouping: migrated, by: { $0.id!} ).mapValues { $0[0] }
        return (byId, wasMigrated)
    }

    func mergeNotes(_ remoteNotes: Notes) -> MergeStatus {
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
        self._notes = newLocalNotes
        return MergeStatus(needsUpload: needsUpload, needsLocalRedraw: needsLocalRedraw)
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
        } catch let error as NSError {
            print("Error: \(error.domain)")
        }
    }
}

struct MergeStatus {
    let needsUpload: Bool
    let needsLocalRedraw: Bool
}
