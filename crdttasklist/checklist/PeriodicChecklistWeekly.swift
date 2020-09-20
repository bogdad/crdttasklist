//
//  PeriodicChecklistWeekly.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-09-06.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

struct PeriodicChecklistWeekly: PeriodicChecklist, Codable, Equatable, Mergeable {

  var intensityCache: Double?
  var storage: CRDT
  var checks: DeletionsInsertions

  init() {
    storage = CRDT("")
    checks = DeletionsInsertions(Date.distantPast)
  }

  init(_ storage: CRDT, _ checks: DeletionsInsertions) {
    self.storage = storage
    self.checks = checks
  }

  func fromString() -> Int {
    guard let res = maybeFromString() else {
      fatalError("bad state")
    }
    return res
  }

  func maybeFromString() -> Int? {
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

  mutating func clear() {
    let descr = storage.to_string()
    guard
      let match = ChecklistCRDT.weeklyRegEx.firstMatch(
        in: descr, options: [], range: NSRange(location: 0, length: descr.utf8.count))
    else {
      return
    }
    storage.replace(match.range(at: 0).to_interval(), "")
    intensityCache = nil
  }

  mutating func intensity() -> Double {
    if let itensityCache = intensityCache {
      return itensityCache
    }
    let res = intensityInner()
    intensityCache = res
    return res
  }
  private func intensityInner() -> Double {
    if !isSet() {
      return 0
    }
    let curDate = Date()
    let weekStartDate = start(curDate)
    let endDate = end(curDate)
    let checkTime = checks.lastCreatedDate() ?? Date.distantPast

    print("\(weekStartDate) \(endDate) \(checkTime) ")
    if weekStartDate < checkTime {
      return 0
    } else {
      let start = curDate
      if start > endDate {
        return 1
      }
      let secondsLeft: Double = endDate.timeIntervalSince1970 - start.timeIntervalSince1970
      let weekly = get()!
      let secondsTotal: Double = Double(weekly * 24 * 60 * 60)
      let interval: Double = (secondsTotal - secondsLeft) / secondsTotal
      if interval < 0 {
        return 0
      }
      print("\(start) \(secondsLeft) \(secondsTotal) \(interval)")
      return interval
    }
  }

  func isSet() -> Bool {
    return maybeFromString() != nil
  }

  func get() -> Int? {
    return maybeFromString()
  }

  func start(_ curDate: Date) -> Date {
    let gregorian = Calendar.current
    let sunday = gregorian.date(
      from: gregorian.dateComponents([.yearForWeekOfYear, .weekOfYear], from: curDate))!
    return gregorian.date(byAdding: .day, value: 1, to: sunday)!
  }

  func end(_ curDate: Date) -> Date {
    let gregorian = Calendar.current
    let sunday = gregorian.date(
      from: gregorian.dateComponents([.yearForWeekOfYear, .weekOfYear], from: curDate))!
    return gregorian.date(byAdding: .day, value: 7, to: sunday)!
  }

  func isCompleted() -> Bool {
    if !isSet() {
      return false
    }
    let completeDate = checks.lastCreatedDate() ?? Date.distantPast
    return completeDate > start(Date())
  }

  mutating func set(_ weekday: Int) {
    if !isSet() {
      intensityCache = nil
      storage.replace(Interval(0, 0), toString(weekday))
    } else {
      let descr = storage.to_string()
      guard
        let match = ChecklistCRDT.weeklyRegEx.firstMatch(
          in: descr, options: [], range: NSRange(location: 0, length: descr.utf8.count))
      else {
        return
      }
      storage.replace(match.range(at: 0).to_interval(), toString(weekday))
      intensityCache = nil
    }
  }


  func toString(_ weekday: Int) -> String {
    return "weekly: \(weekday)"
  }

  mutating func complete() {
    if !isCompleted() {
      checks.markCreated()
      intensityCache = nil
    }
  }

  mutating func uncomplete() {
    if isCompleted() {
      checks.markDeleted()
      intensityCache = nil
    }
  }

  mutating func editing_finished() {
    storage.editing_finished()
  }

  func to_string() -> String {
    return storage.to_string()
  }

  mutating func tryMigrate() -> Bool {
    var res = checks.tryMigrate()
    if storage.tryMigrate() {
      res = true
    }
    return res
  }

  mutating func merge(_ other: PeriodicChecklistWeekly) -> (CRDTMergeResult, Self) {
    let (storageMerge, nv) = storage.merge(other.storage)
    self.storage = nv
    var res = CRDTMergeResult(selfChanged: false, otherChanged: false)
    res.merge(storageMerge)
    let (checkMerge, nvc) = checks.merge(other.checks)
    self.checks = nvc
    res.merge(checkMerge)
    return (res, self)
  }

  func modificationDate() -> Date {
    return Swift.max(storage.modificationDate(), checks.modificationDate())
  }

  mutating func newSession() {
    storage.new_session()
  }

  typealias Item = Int
}

extension PeriodicChecklistWeekly: Storable {
  mutating func commitEvents(_ appState: AppState) -> [Event] {
    let storageEvents = self.storage.commitEvents(appState) as! [CRDTEvent]
    let checkEvents = self.checks.commitEvents(appState) as! [DeletionsInsertionsEvent]
    let periodicWeeklyEvents = PeriodicChecklistWeeklyEvent(
      storageEvents: storageEvents,
      checksEvents: checkEvents)
    return [periodicWeeklyEvents]
  }
}
