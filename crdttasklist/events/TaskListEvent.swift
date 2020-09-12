//
//  TaskListEvent.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-06-27.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

struct DateEvent: Event, Hashable {
  var date: Date
  func getHash() -> Int {
    return hashValue
  }
}

struct CRDTEvent: Event, Hashable {
  var editorEvents: [EditorEvent]
  var deletionsInsertionsEvents: [DeletionsInsertionsEvent]
  var lastModificationDateEvents: [DateEvent]
  func getHash() -> Int {
    return hashValue
  }
}

struct PeriodicChecklistDailyEvent: Event, Hashable {
  var storageEvents: [CRDTEvent]
  var checksEvents: [DeletionsInsertionsEvent]
  func getHash() -> Int {
    return hashValue
  }
}

struct PeriodicChecklistWeeklyEvent: Event, Hashable {
  var storageEvents: [CRDTEvent]
  var checksEvents: [DeletionsInsertionsEvent]
  func getHash() -> Int {
    return hashValue
  }
}

struct ChecklistCRDTEvent: Event, Hashable {
  var dailyEvents: [PeriodicChecklistDailyEvent]
  var weeklyEvents: [PeriodicChecklistWeeklyEvent]
  func getHash() -> Int {
    return hashValue
  }
}

struct NoteEvent: Event, Hashable {
  var id: Int64
  var crdtEvents: [CRDTEvent]
  var checklistCRDTEvents: [ChecklistCRDTEvent]
  func getId() -> Int64 {
    return id
  }
  func getHash() -> Int {
    return hashValue
  }
}
