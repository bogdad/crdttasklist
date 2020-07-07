//
//  Event.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 5/24/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
import Foundation

protocol Event: Codable {
    func getHash() -> Int
}

struct EngineEvent: Event, Hashable {
  var revs: [Revision]
  var text: Rope
  var tombstones: Rope
  var deletesFromUnion: Subset
  func getHash() -> Int {
    return hashValue
  }
}

struct EditorEvent: Event, Hashable {
  var engineEvents: [EngineEvent]
  func getHash() -> Int {
    return hashValue
  }
}

struct DeletionsInsertionsEvent: Event, Hashable {
  var insertion: Pair

  struct Pair: Codable, Hashable {
    var date: Date
    var type: DeletionsInsertionsType
  }
  func getHash() -> Int {
    return hashValue
  }
}
