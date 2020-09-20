//
//  RemoteState.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-07-01.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import HLClock
import SwiftyDropbox

class AppState {
  static let shared = AppState()
  static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask)
    .first!
  static let ArchiveURL = DocumentsDirectory.appendingPathComponent("appstate")

  var appStateCodable = AppStateCodable()

  func currentEventTime() -> Int64 {
    let res = HLClock.global.now()
    appStateCodable.time = res
    return res
  }

  func onAppStart() {
    if UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .phone {
      let dropboxAppKey = "yp4guugaz0yyawo"
      DropboxClientsManager.setupWithAppKey(dropboxAppKey)
    } else {
      let dropboxAppKey = "yp4guugaz0yyawo"
      DropboxClientsManager.setupWithAppKey(dropboxAppKey)
    }

    ensureAllFilepathsCreated()
    loadState()
    if appStateCodable.time > 0 {
      HLClock.global.update(m: appStateCodable.time)
    }
  }

  func onAppStop() {
    saveState()
  }

  func onAppBackground() {
    saveState()
  }

  private func ensureAllFilepathsCreated() {
    try! FileManager.default.createDirectory(at: Note.ArchiveEventURL, withIntermediateDirectories: true, attributes: nil)
  }

  func saveState() {
    FileUtils.saveToFileJson(obj: appStateCodable, url: AppState.ArchiveURL)
  }

  func currentNodeId() -> String {
    return UIDevice.current.identifierForVendor!.uuidString
  }

  private func loadState() {
    let state = FileUtils.loadFromFileJson(type: AppStateCodable.self, url: AppState.ArchiveURL)
    if state != nil {
      appStateCodable = state!
    }
  }

  struct AppStateCodable: Codable {
    var time: Int64 = 0
    var lastEventFrom: [String : Int] = [:]
  }
}
