//
//  TaskListEvent.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-06-27.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

struct DateEvent: Event {
  var date: Date
}

struct CRDTEvent: Event {
  var editorEvents: [EditorEvent]
  var deletionsInsertionsEvents: [DeletionsInsertionsEvent]
  var lastModificationDateEvents: [DateEvent]
}

struct PeriodicChecklistDailyEvent: Event {
  var storageEvents: [CRDTEvent]
  var checksEvents: [DeletionsInsertionsEvent]
}

struct ChecklistCRDTEvent: Event {
  var storageEvents: [CRDTEvent]
  var checksWeeklyEvents: [DeletionsInsertionsEvent]
  var dailyEvents: [PeriodicChecklistDailyEvent]
}

struct NoteEvent: Event {
  var crdtEvents: [CRDTEvent]
  var checklistCRDTEvents: [ChecklistCRDTEvent]
}
