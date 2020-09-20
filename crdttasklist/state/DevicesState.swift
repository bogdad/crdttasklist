//
//  DevicesState.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-09-20.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

class DevicesState {
  static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask)
    .first!
  static let TempURL = DocumentsDirectory.appendingPathComponent("temp-all-devices")

  var devicesStateCodable: DevicesStateCodable?

  init() {
    self.devicesStateCodable = DevicesStateCodable()
  }

  static func load(_ url:URL, _ closure: (DevicesState?) -> Void) {
    let state = FileUtils.loadFromFileJson(type: DevicesStateCodable.self, url: url)
    let res = DevicesState()
    res.devicesStateCodable = state!
    closure(res)
  }

  func save(_ url: URL) {
    FileUtils.saveToFileJson(obj: devicesStateCodable!, url: url)
  }

  func addMeToKnownDevices() -> Bool {
    let currentDevice = AppState.shared.currentNodeId()
    let devices = devicesStateCodable?.devices ?? []
    if !devices.contains(currentDevice) {
      devicesStateCodable!.devices.append(currentDevice)
      return true
    }
    return false
  }

}

class DevicesStateCodable: Codable {
  var devices: [String]
  init() {
    devices = []
  }
}
