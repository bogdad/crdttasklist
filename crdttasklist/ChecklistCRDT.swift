//
//  ChecklistCrdt.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-16.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

struct ChecklistCRDT: Codable {

    static let dailyRegEx = try! NSRegularExpression(pattern: "daily: ([0-9]{2}):([0-9]{2})")

    var lastModificationDate: Date
    /*
     Storage:
     empty - not set
     or:
     daily: 23:59
     */
    var storage: CRDT
    var lastCheckTime: Date?

    init() {
        lastModificationDate = Date()
        lastCheckTime = Date()
        storage = CRDT("")
    }

    mutating func merge(_ other: ChecklistCRDT) -> CRDTMergeResult {
        return CRDTMergeResult(selfChanged: false, otherChanged: false)
    }

    func modificationDate() -> Date {
        return lastModificationDate
    }

    func isSet() -> Bool {
        return storage.editor.get_buffer().len() > 0
    }

    func getDaily() -> (Int, Int)? {
        if !isSet() {
            return nil
        }
        return dailyFromString(storage.to_string())
    }

    mutating func clear() {
        storage.replace(Interval(0, storage.len()), "")
    }

    func dailyFromString(_ str: String) -> (Int, Int) {
        let descr = storage.to_string()
        guard let match = ChecklistCRDT.dailyRegEx.firstMatch(in: descr, options: [], range: NSRange(location: 0, length: descr.utf8.count)) else {
            fatalError("bad state")
        }
        guard let hourRange = Range(match.range(at: 1), in: descr) else {
            fatalError("bad state")
        }
        guard let minutesRange = Range(match.range(at: 2), in: descr) else {
            fatalError("bad state")
        }
        guard let hours = Int(descr[hourRange]) else {
            fatalError("bad state")
        }
        guard let minutes = Int(descr[minutesRange]) else {
            fatalError("bad state")
        }
        return (hours, minutes)
    }

    func dailyAsString(_ hour: Int, _ minute: Int) -> String {
        return "daily: \(hour.pad_to(2)):\(minute.pad_to(2))"
    }

    mutating func setDaily(_ daily: (Int, Int)) {
        if !isSet() {
            storage.replace(Interval(0, 0), dailyAsString(daily.0, daily.1))
        } else {
            storage.replace(Interval(0, storage.editor.get_buffer().len()), dailyAsString(daily.0, daily.1))
        }
    }

    mutating func newSession() {
        storage.new_session()
    }

    mutating func tryMigrate() -> Bool {
        var res = false
        if lastCheckTime == nil {
            lastCheckTime = Date.distantPast
            res = true
        }
        return res
    }
}
