//
//  Event.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 5/24/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//

protocol Event: Codable {
    
}

struct EngineEvent: Event {
    var revs: [Revision]
    var text: Rope
    var tombstones: Rope
    var deletesFromUnion: Subset
}

struct EditorEvent: Event {
    var engineEvent: EngineEvent
}

struct DeletionsInsertionsEvent: Event {
    var insertions: DeletionsInsertions.DeletionsInsertionsMap
}
