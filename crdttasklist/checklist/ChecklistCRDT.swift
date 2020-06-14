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
    static let weeklyRegEx = try! NSRegularExpression(pattern: "weekly: ([0-6])")

    // not used
    var lastModificationDate: Date
    /*
     Storage:
     empty - not set
     or:
     daily: 23:59
     weekly: 0-6
     */
    var storage: CRDT
    var lastCheckTime: Date?

    // deprecate soon
    var checks: DeletionsInsertions?
    var checksDaily: DeletionsInsertions?
    var checksWeekly: DeletionsInsertions?


    var intensityDailyCache: Double?
    var intensityWeeklyCache: Double?

    init() {
        lastModificationDate = Date()
        lastCheckTime = Date.distantPast
        storage = CRDT("")
        checks = DeletionsInsertions(Date.distantPast)
        checksDaily = DeletionsInsertions(Date.distantPast)
        checksWeekly = DeletionsInsertions(Date.distantPast)
    }

    mutating func merge(_ other: ChecklistCRDT) -> CRDTMergeResult {
        let storageMerge = storage.merge(other.storage)
        var res = CRDTMergeResult(selfChanged: false, otherChanged: false)
        res.merge(storageMerge)
        res.merge(checksDaily!.merge(other.checksDaily!))
        res.merge(checksWeekly!.merge(other.checksWeekly!))
        intensityDailyCache = nil
        intensityWeeklyCache = nil
        return res
    }

    mutating func tryMigrate() -> Bool {
        var res = storage.tryMigrate()
        if let _ = checks {
        } else {
            checks = DeletionsInsertions(Date.distantPast)
            res = true
        }
        if let _ = checksDaily {
        } else {
            checksDaily = checks
            res = true
        }
        if let _ = checksWeekly {
        } else {
            checksWeekly = DeletionsInsertions(Date.distantPast)
            res = true
        }
        return res
    }

    func modificationDate() -> Date {
        return Swift.max(checks!.modificationDate(),
                         checksDaily!.modificationDate(),
                         checksWeekly!.modificationDate(),
                         storage.modificationDate())
    }

    mutating func intensityDaily() -> Double {
        if let intensityDailyCache = intensityDailyCache {
            return intensityDailyCache
        }
        let res = intensityDailyInner()
        intensityDailyCache = res
        return res
    }
    private func intensityDailyInner() -> Double {
        if !isSetDaily() {
            return 0
        }
        let curDate = Date()
        let dayStartDate = dateStartDay(curDate)
        let endDate = dateEnd(curDate)
        let checkTime = checksDaily!.lastCreatedDate() ?? Date.distantPast

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

    func isSetDaily() -> Bool {
        return maybeDailyFromString() != nil
    }

    func isCompletedDaily() -> Bool {
        if !isSetDaily() {
            return false
        }
        let completeDate = checksDaily?.lastCreatedDate() ?? Date.distantPast
        return completeDate > dateStartDay(Date())
    }

    mutating func completeDaily() {
        if !isCompletedDaily() {
            checksDaily!.markCreated()
            intensityDailyCache = nil
        }
    }

    mutating func uncompleteDaily() {
        if isCompletedDaily() {
            checksDaily!.markDeleted()
            intensityDailyCache = nil
        }
    }

    func getDaily() -> (Int, Int)? {
        return maybeDailyFromString()
    }

    mutating func clearDaily() {
        let descr = storage.to_string()
        guard let match = ChecklistCRDT.dailyRegEx.firstMatch(in: descr, options: [], range: NSRange(location: 0, length: descr.utf8.count)) else {
            return
        }
        storage.replace(match.range(at: 0).to_interval(), "")
        intensityDailyCache = nil
    }

    func maybeDailyFromString() -> (Int, Int)? {
        let descr = storage.to_string()
        guard let match = ChecklistCRDT.dailyRegEx.firstMatch(in: descr, options: [], range: NSRange(location: 0, length: descr.utf8.count)) else {
            return nil
        }
        guard let hourRange = Range(match.range(at: 1), in: descr) else {
            return nil
        }
        guard let minutesRange = Range(match.range(at: 2), in: descr) else {
            return nil
        }
        guard let hours = Int(descr[hourRange]) else {
            return nil
        }
        guard let minutes = Int(descr[minutesRange]) else {
            return nil
        }
        return (hours, minutes)
    }

    func dailyFromString(_ str: String) -> (Int, Int) {
        guard let res = maybeDailyFromString() else {
            fatalError("bad state")
        }
        return res
    }

    func dailyAsString(_ hour: Int, _ minute: Int) -> String {
        return "daily: \(hour.pad_to(2)):\(minute.pad_to(2))"
    }

    mutating func setDaily(_ daily: (Int, Int)) {
        if !isSetDaily() {
            intensityDailyCache = nil
            storage.replace(Interval(0, 0), dailyAsString(daily.0, daily.1))
        } else {
            intensityDailyCache = nil
            storage.replace(Interval(0, storage.editor.get_buffer().len()), dailyAsString(daily.0, daily.1))
        }
    }

    func to_string() -> String {
        return storage.to_string()
    }

    mutating func newSession() {
        storage.new_session()
    }

    mutating func editing_finished() {
        storage.editing_finished()
    }

    func maybeWeeklyFromString() -> Int? {
        let descr = storage.to_string()
        guard let match = ChecklistCRDT.weeklyRegEx.firstMatch(in: descr, options: [], range: NSRange(location: 0, length: descr.utf8.count)) else {
            return nil
        }
        guard let weekdayRange = Range(match.range(at: 1), in: descr) else {
            return nil
        }
        guard let weekday = Int(descr[weekdayRange]) else {
            return nil
        }
        return weekday
    }


    mutating func clearWeekly() {
        let descr = storage.to_string()
        guard let match = ChecklistCRDT.weeklyRegEx.firstMatch(in: descr, options: [], range: NSRange(location: 0, length: descr.utf8.count)) else {
            return
        }
        storage.replace(match.range(at: 0).to_interval(), "")
        intensityWeeklyCache = nil
    }

    mutating func intensityWeekly() -> Double {
        if let itensityWeeklyCache = intensityWeeklyCache {
            return itensityWeeklyCache
        }
        let res = intensityWeeklyInner()
        intensityWeeklyCache = res
        return res
    }
    private func intensityWeeklyInner() -> Double {
        if !isSetWeekly() {
            return 0
        }
        let curDate = Date()
        let weekStartDate = weekStart(curDate)
        let endDate = weekEnd(curDate)
        let checkTime = checksWeekly!.lastCreatedDate() ?? Date.distantPast

        print("\(weekStartDate) \(endDate) \(checkTime) ")
        if weekStartDate < checkTime {
            return 0
        } else {
            let start = curDate
            if start > endDate {
                return 1
            }
            let secondsLeft: Double = endDate.timeIntervalSince1970 - start.timeIntervalSince1970
            let weekly = getWeekly()!
            let secondsTotal: Double = Double(weekly * 24 * 60 * 60)
            let interval: Double = (secondsTotal - secondsLeft) / secondsTotal
            if interval < 0 {
                return 0
            }
            print("\(start) \(secondsLeft) \(secondsTotal) \(interval)")
            return interval
        }
    }

    func weekStart(_ curDate: Date) -> Date {
        let gregorian = Calendar.current
        let sunday = gregorian.date(from: gregorian.dateComponents([.yearForWeekOfYear, .weekOfYear], from: curDate))!
        return gregorian.date(byAdding: .day, value: 1, to: sunday)!
    }

    func weekEnd(_ curDate: Date) -> Date {
        let gregorian = Calendar.current
        let sunday = gregorian.date(from: gregorian.dateComponents([.yearForWeekOfYear, .weekOfYear], from: curDate))!
        return gregorian.date(byAdding: .day, value: 7, to: sunday)!
    }

    func getWeekly() -> Int? {
        return maybeWeeklyFromString()
    }

    func isSetWeekly() -> Bool {
        return maybeWeeklyFromString() != nil
    }

    func isCompletedWeekly() -> Bool {
        if !isSetWeekly() {
            return false
        }
        let completeDate = checksWeekly?.lastCreatedDate() ?? Date.distantPast
        return completeDate > weekStart(Date())
    }

    mutating func completeWeekly() {
        if !isCompletedWeekly() {
            checksWeekly!.markCreated()
            intensityWeeklyCache = nil
        }
    }

    mutating func uncompleteWeekly() {
        if isCompletedWeekly() {
            checksWeekly!.markDeleted()
            intensityWeeklyCache = nil
        }
    }

    func weeklyFromString(_ str: String) -> Int {
        guard let res = maybeWeeklyFromString() else {
            fatalError("bad state")
        }
        return res
    }

    func weeklyAsString(_ weekday: Int) -> String {
        return "weekly: \(weekday)"
    }

    mutating func setWeekly(_ weekday: Int) {
        if !isSetWeekly() {
            intensityWeeklyCache = nil
            storage.replace(Interval(0, 0), weeklyAsString(weekday))
        } else {
            let descr = storage.to_string()
            guard let match = ChecklistCRDT.weeklyRegEx.firstMatch(in: descr, options: [], range: NSRange(location: 0, length: descr.utf8.count)) else {
                return
            }
            storage.replace(match.range(at: 0).to_interval(), weeklyAsString(weekday))
            intensityWeeklyCache = nil
        }
    }


}
