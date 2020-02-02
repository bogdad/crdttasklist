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

    func loadNotes(_ client: DropboxClient) {
        let destination: (URL, HTTPURLResponse) -> URL = { temporaryURL, response in
            return try! Note.ArchiveURL.asURL()
        }
        client.files.download(path: "/notes", overwrite: true, destination: destination)
        .response { response, error in
            if let response = response {
                print(response)
            } else if let error = error {
                print(error)
            }
        }
        .progress { progressData in
            print(progressData)
        }
        let fileNotes = NSKeyedUnarchiver.unarchiveObject(withFile: Note.ArchiveURL.path) as? [Note]
        notes = fileNotes ?? []
    }

    func saveNotes() {
        let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(self.notes, toFile: Note.ArchiveURL.path)
        print(isSuccessfulSave)
        guard let client = DropboxClientsManager.authorizedClient
        else {
                fatalError("cant happen")
        }
        let request = client.files.upload(path: "/notes", mode: .overwrite, input: try! Note.ArchiveURL.asURL())
            .response { response, error in
                if let response = response {
                    print(response)
                } else if let error = error {
                    print(error)
                }
            }
            .progress { progressData in
                print(progressData)
        }
    }
}
