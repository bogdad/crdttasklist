//
//  NoteStorage.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-01-27.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import SwiftyDropbox

class NoteStorage {
    static let shared = NoteStorage()

    var notes: [Note] = []
    var rev: String?
    var debugShown = false
    var currentNote: Note?

    func editingFinished(_ crdt: CRDT) {
        if currentNote == nil {
            currentNote = Note.newNote()
        }
        currentNote?.update(crdt)
    }

    func isStorageLinked() -> Bool {
        if DropboxClientsManager.authorizedClient != nil {
            return true
        }
        return false
    }

    func update(note: inout Note, newName: String, newText: String) {

    }

    func setNote(_ row: NSInteger, _ note: inout Note) {
        notes[row] = note
        saveNotes()
    }

    func append(_ note: inout Note) {
        notes.append(note)
        saveNotes()
    }

    func remove(_ row: NSInteger) {
        notes.remove(at: row)
        saveNotes()
    }

    func move(_ sourceIndex: NSInteger, _ destinationIndex: NSInteger) {
        let itemToMove = notes[sourceIndex]
        notes.remove(at: sourceIndex)
        notes.insert(itemToMove, at: destinationIndex)
        saveNotes()
    }

    func getNotes() -> [Note] {
        return notes
    }

    func loadNotes() -> Bool {
        guard let notes = loadFrom(toUrl: try! Note.ArchiveURL.asURL()) else {
            if isStorageLinked() {
                conflictDetected()
            }
            return false
        }
        self.notes = notes
        if isStorageLinked() {
            conflictDetected()
        }
        return true
    }

    func saveNotes() {
        FileUtils.saveToFile(obj: self.notes, url: Note.ArchiveURL)

        conflictDetected()
    }

    private func loadFrom(toUrl: URL) -> [Note]? {
        let fileNotes = FileUtils.loadFromFile(type: [Note].self, url: toUrl)
        guard let n = fileNotes else {
            return nil
        }
        let byId: [Note] = Array(Dictionary(grouping: n, by: { $0.id!} ).mapValues({ $0[0] }).values)
        return Array(Dictionary(grouping: byId, by: { $0.dedupHash() }).mapValues({ $0[0] }).values.sortedById())
    }

    private func downloadFromDropbox(toUrl: URL, closure: @escaping ([Note]?, String?) -> Void) {
        guard let client = DropboxClientsManager.authorizedClient else {
            fatalError("bad state")
        }
        let destination: (URL, HTTPURLResponse) -> URL = { temporaryURL, response in
            return toUrl
        }
        client.files.download(path: "/notes", overwrite: true, destination: destination)
        .response { response, error in
            if let response = response {
                guard let fileNotes = self.loadFrom(toUrl: toUrl) else {
                    // TODO: what are we doing if we consistently cant download/parse from dropbox
                    return
                }
                print("downloadFromDropBox: downoladed \(fileNotes.count) with revision \(response.0.rev)")
                DispatchQueue.main.async {
                    closure(fileNotes, response.0.rev)
                }
            } else if let error = error {
                switch error {
                case .routeError(let fileDownloadError, _, _, _):
                    switch fileDownloadError.unboxed {
                    case .path(let pathError):
                        switch pathError {
                        case .notFound:
                            DispatchQueue.main.async {
                                print("downloadFromDropBox: downolad not found")
                                closure(nil, nil)
                            }
                        default:
                            fatalError("handle it!")
                        }
                    case .other:
                        fatalError(fileDownloadError.unboxed.description)
                    default:
                        fatalError("handle it!")
                    }
                default:
                    fatalError("handle it!")
                }
            }
        }
    }

    func conflictDetected() {
        guard let client = DropboxClientsManager.authorizedClient
        else {
                fatalError("cant happen")
        }
        self.downloadFromDropbox(toUrl: Note.TempArchiveURL, closure: { (otherNotes, rev) in

            if otherNotes != nil {
                let (mergedNotes, mergeStatus) = self.mergeNotes(self.notes, otherNotes!)
                self.notes = mergedNotes
                if mergeStatus.needsLocalRedraw {
                    self.notesChangedRemotely()
                }
                if mergeStatus.needsUpload {
                    print("conflictDetected: needs upload, uploading \(self.notes.count)")
                    let _ = client.files.upload(path: "/notes",
                                                mode: .update(rev!),
                                                strictConflict: true,
                                                input: try! Note.ArchiveURL.asURL())
                        .response { response, error in
                            self.handleUpload(response, error)
                        }
                }
            } else {
                _ = client.files.upload(path: "/notes",
                                        mode: .add,
                                        strictConflict: true,
                                        input: try! Note.ArchiveURL.asURL())
                    .response { response, error in
                        self.handleUpload(response, error)
                    }
            }

        });
    }

    func handleUpload(_ response: Files.FileMetadata?, _ error: CallError<Files.UploadError>?) {
        if response != nil {
            print("handleUpload: successfuly uploaded")
        } else if let error = error {
            switch (error) {
            case .routeError(let uploadError, _, _, _):
                switch (uploadError.unboxed) {
                case .path(let uploadError):
                    switch uploadError.reason {
                    case .conflict(_):
                        DispatchQueue.main.async {
                            self.conflictDetected()
                        }
                    default:
                        fatalError("should not happen")
                    }
                default:
                    fatalError("should not happen")
                }
            default:
                fatalError("should not happen")
            }
        }
    }

    func mergeNotes(_ localNotes: [Note], _ remoteNotes: [Note]) -> ([Note], MergeStatus) {
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

        return (newLocalNotes, MergeStatus(needsUpload: needsUpload, needsLocalRedraw: needsLocalRedraw))
    }

    func notesChangedRemotely() {
        NotificationCenter.default.post(name: NSNotification.Name("notesChangedRemotely"), object: nil)
    }

    func checkRemotes() {
        if isStorageLinked() {
            conflictDetected()
        }
    }

    func eraseAllData() {
        self.notes = []
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
