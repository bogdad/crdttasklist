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
        notes = loadFrom(toUrl: try! Note.ArchiveURL.asURL())
        if isStorageLinked() {
            conflictDetected()
        }
        return true
    }

    func saveNotes() {
        let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(self.notes, toFile: Note.ArchiveURL.path)
        print(isSuccessfulSave)
        conflictDetected()
    }

    private func loadFrom(toUrl: URL) -> [Note] {
        let fileNotes = NSKeyedUnarchiver.unarchiveObject(withFile: toUrl.path) as? [Note]
        let n = fileNotes ?? []
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
                let fileNotes = self.loadFrom(toUrl: toUrl)
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
                    default:
                        fatalError("handle it!")
                    }
                default:
                    fatalError("handle it!")
                }
            }
        }
        .progress { progressData in
            print(progressData)
        }
    }

    func conflictDetected() {
        guard let client = DropboxClientsManager.authorizedClient
        else {
                fatalError("cant happen")
        }
        self.downloadFromDropbox(toUrl: Note.TempArchiveURL, closure: { (otherNotes, rev) in

            if otherNotes != nil {
                let (mergedNotes, wasChange) = self.mergeNotes(self.notes, otherNotes!)
                self.notes = mergedNotes
                if wasChange {
                    print("conflictDetected: was a change, uploading \(self.notes.count)")
                    self.notesChangedRemotely()
                    let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(self.notes, toFile: Note.ArchiveURL.path)
                    let request = client.files.upload(path: "/notes", mode: .update(rev!), strictConflict: true, input: try! Note.ArchiveURL.asURL())
                        .response { response, error in
                            self.handleUpload(response, error)
                        }
                        .progress { progressData in
                            print(progressData)
                    }
                }
            } else {
                let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(self.notes, toFile: Note.ArchiveURL.path)
                let request = client.files.upload(path: "/notes", mode: .add, strictConflict: true, input: try! Note.ArchiveURL.asURL())
                    .response { response, error in
                        self.handleUpload(response, error)
                    }
                    .progress { progressData in
                        print(progressData)
                }
            }

        });
    }

    func handleUpload(_ response: Files.FileMetadata?, _ error: CallError<Files.UploadError>?) {
        if let response = response {
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

    func mergeNotes(_ selfNotes: [Note], _ otherNotes: [Note]) -> ([Note], Bool) {
        var selfDict = Dictionary(grouping: selfNotes, by: { $0.id! }).mapValues({$0[0]})
        let otherDict = Dictionary(grouping: otherNotes, by: { $0.id! }).mapValues({$0[0]})
        var numDiff = 0
        selfDict.merge(otherDict, uniquingKeysWith: { (left, right) -> Note in
            let (res, changed) = left.merge(right)
            if changed {
                print("mergeNotes: node \(left.id!) changed")
                numDiff += 1
            }
            return res
        })

        // TODO: handle deletions
        let res = Array(selfDict.values.sortedById())
        let numMissingLocally = res.count - selfNotes.count
        let numMissingRemotely = res.count - otherNotes.count
        print("mergeNotes: before \(selfNotes.count) other \(otherNotes.count) after \(res.count)")
        print("mergeNotes: numMissingLocally \(numMissingLocally) numMissingRemotely \(numMissingRemotely) numDiff \(numDiff) ")
        return (res, numMissingLocally + numMissingRemotely + numDiff != 0)
    }

    func notesChangedRemotely() {
        NotificationCenter.default.post(name: NSNotification.Name("notesChangedRemotely"), object: nil)
    }

    func checkRemotes() {
        if isStorageLinked() {
            conflictDetected()
        }
    }
}
