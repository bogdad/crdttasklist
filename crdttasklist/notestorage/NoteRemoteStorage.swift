//
//  NoteRemoteStorage.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-09.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import NIOConcurrencyHelpers
import SwiftyDropbox

class NoteRemoteStorage {

  static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask)
    .first!
  static let MigrationsUrl1 = DocumentsDirectory.appendingPathComponent(
    "noteremotestoragemigrations")

  static let shared = NoteRemoteStorage()
  static let queue = DispatchQueue(label: "remote")

  let noteStorage = NoteStorage.shared
  class Migrations {
    class Migration1: Codable {
      var started = false
      var finished = false
      func start(_ selv: NoteRemoteStorage, _ i: Int) {
        if started {
          return
        }
        if finished {
          return
        }
        guard let client = DropboxClientsManager.authorizedClient else {
          fatalError("bad state")
        }
        started = true
        client.files.moveV2(
          fromPath: selv.remoteSnapshot(), toPath: "\(selv.remoteSnapshot())_backup"
        )
        .response { r, e in
          client.files.copyV2(fromPath: "/notes", toPath: selv.remoteSnapshot())
            .response(completionHandler: { response, error in
              self.started = false
              self.finished = true
              selv.migrations.start(selv, i + 1)
            })
        }
      }
    }
    var migration1: Migration1

    init() {
      migration1 =
        FileUtils.loadFromFile(type: Migration1.self, url: NoteRemoteStorage.MigrationsUrl1)
        ?? Migration1()
    }

    deinit {
      FileUtils.saveToFile(obj: migration1, url: NoteRemoteStorage.MigrationsUrl1)
    }

    func start(_ selv: NoteRemoteStorage, _ i: Int) {
      if i == 0 {
        migration1.start(selv, 0)
      } else {
        // finished
        FileUtils.saveToFile(obj: migration1, url: NoteRemoteStorage.MigrationsUrl1)
      }
    }
  }
  var migrations = Migrations()

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
    let deviceId = AppState.shared.currentNodeId()
    return "/\(deviceId)/\(str)"
  }

  func remoteSnapshot() -> String {
    return remoteNameFrom("notes")
  }

  func remoteEvent(_ id: Int64) -> String {
    return remoteNameFrom("events/\(id)")
  }

  func remoteAllDevices() -> String {
    return "/all_devices"
  }

  func checkRemotes() {
    if isStorageLinked() {
      conflictDetected()
    }
  }

  func isStorageLinked() -> Bool {
    if DropboxClientsManager.authorizedClient != nil {
      NoteRemoteStorage.queue.async {
        self.migrations.start(self, 0)
      }
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

  func upsert(_ path: String, _ url: URL, _ rev: String?) {
    guard let client = DropboxClientsManager.authorizedClient else {
        return
    }
    if let rev = rev {
        let _ = client.files.upload(
          path: path,
          mode: .update(rev),
          strictConflict: true,
          input: url
        )
        .response { response, error in
          self.handleUpload(response, error)
        }
      } else {
        _ = client.files.upload(
          path: self.remoteSnapshot(),
          mode: .add,
          strictConflict: true,
          input: url
        )
        .response { response, error in
          self.handleUpload(response, error)
        }
      }
  }

  func uploadInBackground(_ rev: String?) {
    NoteRemoteStorage.queue.async {
      NoteLocalStorage.justSaveNotes()
      self.upsert(self.remoteSnapshot(), try! Note.ArchiveURL.asURL(), rev)
    }
  }

  func conflictDetected() {
    NoteRemoteStorage.queue.async {
      if !self.isStorageLinked() {
        return
      }
      self.downloadAllDevicesFromDropbox({ () -> Void in 
      self.downloadFromDropbox(
        toUrl: Note.TempArchiveURL,
        closure: { arg in

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

        })
      })
    }
  }

  private func downloadAllDevicesFromDropbox(_ closure: () -> Void) {
    let toUrl = DevicesState.TempURL
    guard let client = DropboxClientsManager.authorizedClient else {
      fatalError("bad state")
    }
    let destination: (URL, HTTPURLResponse) -> URL = { temporaryURL, response in
      return toUrl
    }
    client.files.download(path: remoteAllDevices(), overwrite: true, destination: destination)
      .response { response, error in
        if let response = response {
          DevicesState.load(toUrl,
            { (res) -> Void in
              self.downloadAllDevicesFromDropboxClosure((res!, response.0.rev), closure)
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
                  self.downloadAllDevicesFromDropboxClosure(nil, closure)
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

  private func downloadAllDevicesFromDropboxClosure(_ res: (DevicesState, String)?,_ closure: () -> Void) {
    let devicesState = res?.0 ?? DevicesState()
    if devicesState.addMeToKnownDevices() {
      NoteRemoteStorage.queue.async {
        devicesState.save(DevicesState.TempURL)
        self.upsert(self.remoteAllDevices(), DevicesState.TempURL, res?.1)
      }
    }
    closure()
  }

  private func downloadFromDropbox(toUrl: URL, closure: @escaping ((Notes, String, Bool)?) -> Void)
  {
    guard let client = DropboxClientsManager.authorizedClient else {
      fatalError("bad state")
    }
    let destination: (URL, HTTPURLResponse) -> URL = { temporaryURL, response in
      return toUrl
    }
    client.files.download(path: remoteSnapshot(), overwrite: true, destination: destination)
      .response { response, error in
        if let response = response {
          if response.0.size == 0 {

          }
          NoteLocalStorage.loadFrom(
            toUrl,
            { (res) -> Void in
              guard let (fileNotes, wasMigrated) = res else {
                return
              }
              DispatchQueue.main.async {
                print(
                  "downloadFromDropBox: downoladed \(fileNotes.count) with revision \(response.0.rev)"
                )
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

  func saveEvents(_ events: [NoteEvent]) {
    // TODO: we might die in the middle of uploading, fix
    NoteRemoteStorage.queue.async {
      NoteLocalStorage.saveEvents(events) {
        // called on the local queue
        NoteRemoteStorage.queue.async {
          self.saveEventsInner(events, 0) {
            // called when all events are uploaded
            NoteLocalStorage.deleteEvents(events)
          }
        }
      }
      self.conflictDetected()
    }
  }

  private func saveEventsInner(_ events: [NoteEvent], _ i: Int, _ completion: @escaping () -> Void) {
    // TODO: we might die in the middle of uploading, fix
    guard let client = DropboxClientsManager.authorizedClient else {
      return
    }
    if i >= events.count {
      completion()
    }
    let _ = client.files.upload(
      path: self.remoteEvent(events[i].id),
      mode: .add,
      strictConflict: true,
      input: NoteLocalStorage.eventUrl(events[i])
    ).response { response, error in
      NoteRemoteStorage.queue.async {
        let nextI = i + 1
        if nextI < events.count {
          self.saveEventsInner(events, nextI, completion)
        } else {
          completion()
        }
      }
    }
  }
}
