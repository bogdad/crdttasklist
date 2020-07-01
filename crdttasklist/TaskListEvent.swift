//
//  TaskListEvent.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-06-27.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

struct DateEvent: Event, Hashable {
  var id = UUID()
  var date: Date
  func getId() -> UUID {
    return id
  }
  func getHash() -> Int {
    return hashValue
  }
}

struct CRDTEvent: Event, Hashable {
  var id = UUID()
  var editorEvents: [EditorEvent]
  var deletionsInsertionsEvents: [DeletionsInsertionsEvent]
  var lastModificationDateEvents: [DateEvent]
  func getId() -> UUID {
    return id
  }
  func getHash() -> Int {
    return hashValue
  }
}

struct PeriodicChecklistDailyEvent: Event, Hashable {
  var id = UUID()
  var storageEvents: [CRDTEvent]
  var checksEvents: [DeletionsInsertionsEvent]
  func getId() -> UUID {
    return id
  }
  func getHash() -> Int {
    return hashValue
  }
}

struct ChecklistCRDTEvent: Event, Hashable {
  var id = UUID()
  var storageEvents: [CRDTEvent]
  var checksWeeklyEvents: [DeletionsInsertionsEvent]
  var dailyEvents: [PeriodicChecklistDailyEvent]
  func getId() -> UUID {
    return id
  }
  func getHash() -> Int {
    return hashValue
  }
}

struct NoteEvent: Event, Hashable {
  var id = UUID()
  var crdtEvents: [CRDTEvent]
  var checklistCRDTEvents: [ChecklistCRDTEvent]
  func getId() -> UUID {
    return id
  }
  func getHash() -> Int {
    return hashValue
  }
}
