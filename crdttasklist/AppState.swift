//
//  RemoteState.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-07-01.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import HLClock

class AppState: Codable {
  static let shared = AppState()

  func currentEventTime() -> Int64 {
    return HLClock.global.now()
  }

  func ensureAllFilepathsCreated() {
    try! FileManager.default.createDirectory(at: Note.ArchiveEventURL, withIntermediateDirectories: true, attributes: nil)
  }
}
