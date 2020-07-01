//
//  Event.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 5/24/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
import Foundation

protocol Event: Codable {
    func getId() -> UUID
    func getHash() -> Int
}

struct EngineEvent: Event, Hashable {
  var id = UUID()
  var revs: [Revision]
  var text: Rope
  var tombstones: Rope
  var deletesFromUnion: Subset
  func getId() -> UUID {
    return id
  }
  func getHash() -> Int {
    return hashValue
  }
}

struct EditorEvent: Event, Hashable {
  var id = UUID()
  var engineEvents: [EngineEvent]
  func getId() -> UUID {
    return id
  }
  func getHash() -> Int {
    return hashValue
  }
}

struct DeletionsInsertionsEvent: Event, Hashable {
  var id = UUID()
  var insertion: Pair

  struct Pair: Codable, Hashable {
    var date: Date
    var type: DeletionsInsertionsType
  }
  func getId() -> UUID {
    return id
  }
  func getHash() -> Int {
    return hashValue
  }
}
