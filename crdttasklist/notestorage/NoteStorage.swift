//
//  NoteStorage.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-01-27.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

class NoteStorage {
    static let shared = NoteStorage()

    var _notes: [Note] = []
    var rev: String?
    var debugShown = false
    var currentNote: Note?

    func notes() -> [Note] {
        return _notes
    }

    func editingFinished(_ crdt: CRDT) {
        if currentNote == nil {
            currentNote = Note.newNote()
        }
        currentNote?.update(crdt)
    }


    func update(note: inout Note, newName: String, newText: String) {

    }

    func setNote(_ row: NSInteger, _ note: inout Note) {
        _notes[row] = note
        saveNotes()
    }

    func append(_ note: inout Note) {
        _notes.append(note)
        saveNotes()
    }

    func remove(_ row: NSInteger) {
        _notes.remove(at: row)
        saveNotes()
    }



    func move(_ sourceIndex: NSInteger, _ destinationIndex: NSInteger) {
        let itemToMove = _notes[sourceIndex]
        _notes.remove(at: sourceIndex)
        _notes.insert(itemToMove, at: destinationIndex)
        saveNotes()
    }

    func getNotes() -> [Note] {
        return _notes
    }

    func loadNotes() -> Bool {
        guard let notes = loadFrom(toUrl: try! Note.ArchiveURL.asURL()) else {
            self._notes = []
            saveNotes()
            NoteRemoteStorage.shared.conflictDetected()
            return false
        }
        self._notes = notes
        NoteRemoteStorage.shared.conflictDetected()
        return true
    }

    func saveNotes() {
        FileUtils.saveToFile(obj: self._notes, url: Note.ArchiveURL)
        NoteRemoteStorage.shared.conflictDetected()
    }

    func loadFrom(toUrl: URL) -> [Note]? {
        let fileNotes = FileUtils.loadFromFile(type: [Note].self, url: toUrl)
        guard let n = fileNotes else {
            return nil
        }
        for fileNotes in _notes {
            fileNotes.tryMigrate()
        }
        let byId: [Note] = Array(Dictionary(grouping: n, by: { $0.id!} ).mapValues({ $0[0] }).values)
        return Array(Dictionary(grouping: byId, by: { $0.dedupHash() }).mapValues({ $0[0] }).values.sortedById())
    }





    func mergeNotes(_ remoteNotes: [Note]) -> ([Note], MergeStatus) {
        let localNotes = self.notes()
        var localDict = Dictionary(grouping: localNotes, by: { $0.id! }).mapValues({$0[0]})
        let remoteDict = Dictionary(grouping: remoteNotes, by: { $0.id! }).mapValues({$0[0]})
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
        let newLocalNotes = Array(localDict.values.sortedById())
        let numMissingLocally = newLocalNotes.count - localNotes.count
        let numMissingRemotely = newLocalNotes.count - remoteNotes.count
        print("mergeNotes: local count \(localNotes.count) remote count \(remoteNotes.count) new local count \(newLocalNotes.count)")
        print("mergeNotes: numMissingLocally \(numMissingLocally) numMissingRemotely \(numMissingRemotely)")
        print("mergeNotes: numLocalNewer \(numLocalNewer) numRemoteNewer \(numRemoteNewer) ")

        let needsUpload = numMissingRemotely > 0 || numLocalNewer > 0
        let needsLocalRedraw = numMissingLocally > 0 || numRemoteNewer > 0
        self._notes = newLocalNotes
        return (newLocalNotes, MergeStatus(needsUpload: needsUpload, needsLocalRedraw: needsLocalRedraw))
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
        self._notes = []
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
