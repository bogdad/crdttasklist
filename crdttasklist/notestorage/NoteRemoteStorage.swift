//
//  NoteRemoteStorage.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-09.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import SwiftyDropbox
import NIOConcurrencyHelpers

class NoteRemoteStorage {

    static let shared = NoteRemoteStorage()
    static let queue = DispatchQueue(label: "remote")

    let noteStorage = NoteStorage.shared

    let lock = Lock()
    var updatesQueue: Notes?
    func appendToQueue(_ notes: Notes) {
        lock.withLock {
            updatesQueue = notes
        }
    }

    func popLatest() -> Notes? {
        lock.withLock {
            let res = updatesQueue
            updatesQueue = nil
            return res
        }
    }

    func remoteNameFrom(_ str: String) -> String {
        let deviceId = UIDevice.current.identifierForVendor!.uuidString
        return "/\(deviceId)/\(str)"
    }

    func remoteSnapshot() -> String {
        return remoteNameFrom("notes")
    }

    func checkRemotes() {
        if isStorageLinked() {
            conflictDetected()
        }
    }

    func isStorageLinked() -> Bool {
        if DropboxClientsManager.authorizedClient != nil {
            return true
        }
        return false
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
                            print("dropbox: conflict")
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

    func uploadInBackground(_ rev: String?) {
        NoteRemoteStorage.queue.async {
            guard let client = DropboxClientsManager.authorizedClient else {
                return
            }
            
            NoteLocalStorage.justSaveNotes()
            if let rev = rev {
                let _ = client.files.upload(path: self.remoteSnapshot(),
                                        mode: .update(rev),
                                        strictConflict: true,
                                        input: try! Note.ArchiveURL.asURL())
                .response { response, error in
                    self.handleUpload(response, error)
                }
            } else {
                _ = client.files.upload(path: self.remoteSnapshot(),
                                    mode: .add,
                                    strictConflict: true,
                                    input: try! Note.ArchiveURL.asURL())
                    .response { response, error in
                        self.handleUpload(response, error)
                    }
            }
        }
    }

    func conflictDetected() {
        NoteRemoteStorage.queue.async {
            if !self.isStorageLinked() {
                return
            }
            self.downloadFromDropbox(toUrl: Note.TempArchiveURL, closure: { arg in

                if arg != nil {
                    let otherNotes = arg!.0
                    let rev = arg!.1
                    let wasMigrated = arg!.2
                    let (mergeStatus, newLocalNotes) = self.noteStorage.mergeNotes(otherNotes)
                    if mergeStatus.needsLocalRedraw {
                        self.appendToQueue(newLocalNotes)
                        self.noteStorage.notesChangedRemotely()
                    }
                    if mergeStatus.needsUpload || wasMigrated {
                        NoteLocalStorage.justSaveNotes()
                        print("conflictDetected: needs upload, uploading \(self.noteStorage._notes.count)")
                        self.uploadInBackground(rev)
                    }
                } else {
                    self.uploadInBackground(nil)
                }

            });
        }
    }

    private func downloadFromDropbox(toUrl: URL, closure: @escaping ((Notes, String, Bool)?) -> Void) {
        guard let client = DropboxClientsManager.authorizedClient else {
            fatalError("bad state")
        }
        let destination: (URL, HTTPURLResponse) -> URL = { temporaryURL, response in
            return toUrl
        }
        client.files.download(path: "/notes", overwrite: true, destination: destination)
        .response { response, error in
            if let response = response {
                NoteLocalStorage.loadFrom(toUrl, { (res)->Void in
                    guard let (fileNotes, wasMigrated) = res else {
                        return
                    }
                    DispatchQueue.main.async {
                        print("downloadFromDropBox: downoladed \(fileNotes.count) with revision \(response.0.rev)")
                        closure((fileNotes, response.0.rev, wasMigrated))
                    }
                })
            } else if let error = error {
                switch error {
                case .routeError(let fileDownloadError, _, _, _):
                    switch fileDownloadError.unboxed {
                    case .path(let pathError):
                        switch pathError {
                        case .notFound:
                            DispatchQueue.main.async {
                                print("downloadFromDropBox: downolad not found")
                                closure(nil)
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
}
