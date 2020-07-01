//
//  Event.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 5/24/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
import Foundation

protocol Event: Codable {

}

struct EngineEvent: Event {
  var revs: [Revision]
  var text: Rope
  var tombstones: Rope
  var deletesFromUnion: Subset
}

struct EditorEvent: Event {
  var engineEvents: [EngineEvent]
}

struct DeletionsInsertionsEvent: Event {
  var insertion: Pair

  struct Pair: Codable {
    var date: Date
    var type: DeletionsInsertionsType
  }
}
