//
//  NoteRemoteStorage.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-09.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import SwiftyDropbox

class NoteRemoteStorage {

    static let shared = NoteRemoteStorage()

    let noteStorage = NoteStorage.shared

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


    func conflictDetected() {
        if !isStorageLinked() {
            return
        }
        guard let client = DropboxClientsManager.authorizedClient
        else {
                fatalError("cant happen")
        }
        self.downloadFromDropbox(toUrl: Note.TempArchiveURL, closure: { arg in

            if arg != nil {
                let otherNotes = arg!.0
                let rev = arg!.1
                let wasMigrated = arg!.2
                let mergeStatus = self.noteStorage.mergeNotes(otherNotes)
                if mergeStatus.needsLocalRedraw {
                    self.noteStorage.notesChangedRemotely()
                }
                if mergeStatus.needsUpload || wasMigrated {
                    NoteStorage.shared.saveNotes()
                    print("conflictDetected: needs upload, uploading \(self.noteStorage.notes().count)")
                    let _ = client.files.upload(path: "/notes",
                                                mode: .update(rev),
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
                guard let (fileNotes, wasMigrated) = NoteLocalStorage.loadFrom(toUrl) else {
                    // TODO: what are we doing if we consistently cant download/parse from dropbox
                    return
                }
                print("downloadFromDropBox: downoladed \(fileNotes.count) with revision \(response.0.rev)")
                DispatchQueue.main.async {
                    closure((fileNotes, response.0.rev, wasMigrated))
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
