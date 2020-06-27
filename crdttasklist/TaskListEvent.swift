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
    var editorEvent: EditorEvent
    var deletionsInsertionsEvent: DeletionsInsertionsEvent
    var lastModificationDateEvent: DateEvent
}

struct PeriodicChecklistDailyEvent: Event {
    var storageEvent: CRDTEvent
    var checksEvent: DeletionsInsertionsEvent
}

struct ChecklistCRDTEvent: Event {
    var storageEvent: CRDTEvent
    var checksWeekly: DeletionsInsertionsEvent
    var daily: PeriodicChecklistDailyEvent
}

struct NoteEvent: Event {
    var crdtEvent: CRDTEvent
    var checklistCRDTEvent: ChecklistCRDTEvent
}
