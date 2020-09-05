//
//  ChecklistCrdt.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-16.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

struct ChecklistCRDT: Codable, Equatable, Mergeable {

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

  var daily: PeriodicChecklistDaily?

  var intensityWeeklyCache: Double?

  init() {
    lastModificationDate = Date()
    lastCheckTime = Date.distantPast
    storage = CRDT("")
    checks = DeletionsInsertions(Date.distantPast)
    checksDaily = DeletionsInsertions(Date.distantPast)
    checksWeekly = DeletionsInsertions(Date.distantPast)
    daily = PeriodicChecklistDaily(storage, checksDaily!)
  }

  mutating func merge(_ other: ChecklistCRDT) -> (CRDTMergeResult, Self) {
    let (storageMerge, ns) = storage.merge(other.storage)
    self.storage = ns
    var res = CRDTMergeResult(selfChanged: false, otherChanged: false)
    res.merge(storageMerge)
    let (cdr, ncd) = checksDaily!.merge(other.checksDaily!)
    self.checksDaily = ncd
    res.merge(cdr)
    let (cwr, ncw) = checksWeekly!.merge(other.checksWeekly!)
    self.checksWeekly = ncw
    res.merge(cwr)
    let (dr, nd) = daily!.merge(other.daily!)
    self.daily = nd
    res.merge(dr)
    intensityWeeklyCache = nil
    return (res, self)
  }

  mutating func tryMigrate() -> Bool {
    var res = storage.tryMigrate()
    if var checks = checks {
      if checks.tryMigrate() {
        self.checks = checks
        res = true
      }
    } else {
      checks = DeletionsInsertions(Date.distantPast)
      res = true
    }
    if var checksDaily = checksDaily {
      if checksDaily.tryMigrate() {
        self.checksDaily = checksDaily
        res = true
      }
    } else {
      checksDaily = checks
      res = true
    }
    if var checksWeekly = checksWeekly {
      if checksWeekly.tryMigrate() {
        self.checksWeekly = checksWeekly
        res = true
      }
    } else {
      checksWeekly = DeletionsInsertions(Date.distantPast)
      res = true
    }
    if var daily = daily {
      if daily.tryMigrate() {
        self.daily = daily
        res = true
      }
    } else {
      daily = PeriodicChecklistDaily(storage, checksDaily!)
      res = true
    }
    return res
  }

  func modificationDate() -> Date {
    return Swift.max(
      checks!.modificationDate(),
      checksDaily!.modificationDate(),
      checksWeekly!.modificationDate(),
      storage.modificationDate())
  }

  func to_string() -> String {
    return storage.to_string()
  }

  mutating func newSession() {
    storage.new_session()
  }

  mutating func editing_finished() {
    storage.editing_finished()
    daily?.editing_finished()
  }

  func getDaily() -> (Int, Int)? {
    return daily?.get()
  }
  func isSetDaily() -> Bool {
    return daily!.isSet()
  }
  func isCompletedDaily() -> Bool {
    return daily!.isCompleted()
  }
  mutating func completeDaily() {
    daily!.complete()
  }
  mutating func uncompleteDaily() {
    daily!.uncomplete()
  }
  mutating func setDaily(_ item: (Int, Int)) {
    daily!.set(item)
  }
  mutating func clearDaily() {
    daily!.clear()
  }
  mutating func intensityDaily() -> Double {
    return daily!.intensity()
  }

  func maybeWeeklyFromString() -> Int? {
    let descr = storage.to_string()
    guard
      let match = ChecklistCRDT.weeklyRegEx.firstMatch(
        in: descr, options: [], range: NSRange(location: 0, length: descr.utf8.count))
    else {
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
    guard
      let match = ChecklistCRDT.weeklyRegEx.firstMatch(
        in: descr, options: [], range: NSRange(location: 0, length: descr.utf8.count))
    else {
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
    let sunday = gregorian.date(
      from: gregorian.dateComponents([.yearForWeekOfYear, .weekOfYear], from: curDate))!
    return gregorian.date(byAdding: .day, value: 1, to: sunday)!
  }

  func weekEnd(_ curDate: Date) -> Date {
    let gregorian = Calendar.current
    let sunday = gregorian.date(
      from: gregorian.dateComponents([.yearForWeekOfYear, .weekOfYear], from: curDate))!
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
      guard
        let match = ChecklistCRDT.weeklyRegEx.firstMatch(
          in: descr, options: [], range: NSRange(location: 0, length: descr.utf8.count))
      else {
        return
      }
      storage.replace(match.range(at: 0).to_interval(), weeklyAsString(weekday))
      intensityWeeklyCache = nil
    }
  }
}

extension ChecklistCRDT: Storable {
  mutating func commitEvents(_ appState: AppState) -> [Event] {
    let storageEvents = self.storage.commitEvents(appState) as! [CRDTEvent]
    let checklistWeeklyEvents = self.checksWeekly!.commitEvents(appState) as! [DeletionsInsertionsEvent]
    let dailyEvents = self.daily!.commitEvents(appState) as! [PeriodicChecklistDailyEvent]
    let checklistCRDTEvent = ChecklistCRDTEvent(
      storageEvents: storageEvents,
      checksWeeklyEvents: checklistWeeklyEvents,
      dailyEvents: dailyEvents)
    return [checklistCRDTEvent]
  }
}
