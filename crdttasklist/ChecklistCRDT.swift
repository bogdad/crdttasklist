//
//  ChecklistCrdt.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-16.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

struct ChecklistCRDT: Codable, Equatable {

    static let dailyRegEx = try! NSRegularExpression(pattern: "daily: ([0-9]{2}):([0-9]{2})")

    // not used
    var lastModificationDate: Date
    /*
     Storage:
     empty - not set
     or:
     daily: 23:59
     */
    var storage: CRDT
    var lastCheckTime: Date?

    var checks: DeletionsInsertions?

    init() {
        lastModificationDate = Date()
        lastCheckTime = Date.distantPast
        storage = CRDT("")
        checks = DeletionsInsertions(Date.distantPast)
    }

    mutating func merge(_ other: ChecklistCRDT) -> CRDTMergeResult {
        let storageMerge = storage.merge(other.storage)
        var res = CRDTMergeResult(selfChanged: false, otherChanged: false)
        res.merge(storageMerge)
        res.merge(checks!.merge(other.checks!))
        return res
    }

    func modificationDate() -> Date {
        return Swift.max(checks!.modificationDate(), storage.modificationDate())
    }

    func intensity() -> Double {
        if !isSet() {
            return 0
        }
        let curDate = Date()
        let dayStartDate = dateStartDay(curDate)
        let endDate = dateEnd(curDate)
        let checkTime = checks!.lastCreatedDate() ?? Date.distantPast

        print("\(dayStartDate) \(endDate) \(checkTime) ")
        if dayStartDate < checkTime {
            return 0
        } else {
            let start = curDate
            if start > endDate {
                return 1
            }
            let secondsLeft: Double = endDate.timeIntervalSince1970 - start.timeIntervalSince1970
            let daily = getDaily()!
            var hours = daily.0
            if hours > 8 {
                hours -= 8
            }
            let secondsTotal: Double = Double((hours * 60 + daily.1) * 60)
            let interval: Double = (secondsTotal - secondsLeft) / secondsTotal
            if interval < 0 {
                return 0
            }
            print("\(start) \(secondsLeft) \(secondsTotal) \(interval)")
            return interval
        }
    }

    func dateStartDay(_ curDate: Date) -> Date {
        let calendar = Calendar.current
        var startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: curDate)
        startComponents.hour = 0
        startComponents.minute = 0
        let dayStartDate = calendar.date(from: startComponents)!
        return dayStartDate
    }

    func dateEnd(_ curDate: Date) -> Date {
        let calendar = Calendar.current
        var endComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: curDate)
        let daily = getDaily()!
        endComponents.hour = daily.0
        endComponents.minute = daily.1
        let endDate = calendar.date(from: endComponents)!
        return endDate
    }

    func isSet() -> Bool {
        return storage.editor.get_buffer().len() > 0
    }

    func isCompleted() -> Bool {
        if !isSet() {
            return false
        }
        let completeDate = checks?.lastCreatedDate() ?? Date.distantPast
        return completeDate > dateStartDay(Date())
    }

    mutating func complete() {
        if !isCompleted() {
            checks!.markCreated()
        }
    }

    mutating func uncomplete() {
        if isCompleted() {
            checks!.markDeleted()
        }
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

    func to_string() -> String {
        return storage.to_string()
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

    mutating func editing_finished() {
        storage.editing_finished()
    }

    mutating func tryMigrate() -> Bool {
        var res = storage.tryMigrate()
        if let _ = checks {
        } else {
            checks = DeletionsInsertions(Date.distantPast)
            res = true
        }
        return res
    }
}
