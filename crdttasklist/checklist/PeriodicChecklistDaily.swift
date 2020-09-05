//
//  PeriodicChecklistDaily.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-06-19.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

struct PeriodicChecklistDaily: PeriodicChecklist, Codable, Equatable, Mergeable {
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

  mutating func tryMigrate() -> Bool {
    let res = checks.tryMigrate()
    return res
  }

  mutating func merge(_ other: PeriodicChecklistDaily) -> (CRDTMergeResult, Self) {
    let (storageMerge, nv) = storage.merge(other.storage)
    self.storage = nv
    var res = CRDTMergeResult(selfChanged: false, otherChanged: false)
    res.merge(storageMerge)
    let (checkMerge, nvc) = checks.merge(other.checks)
    self.checks = nvc
    res.merge(checkMerge)
    return (res, self)
  }

  mutating func intensity() -> Double {
    if let intensityCache = intensityCache {
      return intensityCache
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
    let dayStartDate = start(curDate)
    let endDate = end(curDate)
    let checkTime = checks.lastCreatedDate() ?? Date.distantPast

    print("\(dayStartDate) \(endDate) \(checkTime) ")
    if dayStartDate < checkTime {
      return 0
    } else {
      let start = curDate
      if start > endDate {
        return 1
      }
      let secondsLeft: Double = endDate.timeIntervalSince1970 - start.timeIntervalSince1970
      let daily = get()!
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

  func start(_ curDate: Date) -> Date {
    let calendar = Calendar.current
    var startComponents = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: curDate)
    startComponents.hour = 0
    startComponents.minute = 0
    let dayStartDate = calendar.date(from: startComponents)!
    return dayStartDate
  }

  func end(_ curDate: Date) -> Date {
    let calendar = Calendar.current
    var endComponents = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: curDate)
    let daily = get()!
    endComponents.hour = daily.0
    endComponents.minute = daily.1
    let endDate = calendar.date(from: endComponents)!
    return endDate
  }

  func isSet() -> Bool {
    return maybeFromString() != nil
  }

  func isCompleted() -> Bool {
    if !isSet() {
      return false
    }
    let completeDate = checks.lastCreatedDate() ?? Date.distantPast
    return completeDate > start(Date())
  }

  func get() -> (Int, Int)? {
    return maybeFromString()
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

  mutating func set(_ daily: (Int, Int)) {
    if !isSet() {
      intensityCache = nil
      storage.replace(Interval(0, 0), toString((daily.0, daily.1)))
    } else {
      intensityCache = nil
      storage.replace(Interval(0, storage.editor.get_buffer().len()), toString((daily.0, daily.1)))
    }
  }

  func maybeFromString() -> (Int, Int)? {
    let descr = storage.to_string()
    guard
      let match = ChecklistCRDT.dailyRegEx.firstMatch(
        in: descr, options: [], range: NSRange(location: 0, length: descr.utf8.count))
    else {
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

  func fromString() -> (Int, Int) {
    guard let res = maybeFromString() else {
      fatalError("bad state")
    }
    return res
  }

  func toString(_ item: Item) -> String {
    return "daily: \(item.0.pad_to(2)):\(item.1.pad_to(2))"
  }

  mutating func clear() {
    let descr = storage.to_string()
    guard
      let match = ChecklistCRDT.dailyRegEx.firstMatch(
        in: descr, options: [], range: NSRange(location: 0, length: descr.utf8.count))
    else {
      return
    }
    storage.replace(match.range(at: 0).to_interval(), "")
    intensityCache = nil
  }

  mutating func editing_finished() {
    storage.editing_finished()
  }

  typealias Item = (Int, Int)
}

extension PeriodicChecklistDaily: Storable {
  mutating func commitEvents(_ appState: AppState) -> [Event] {
    let storageEvents = self.storage.commitEvents(appState) as! [CRDTEvent]
    let checkEvents = self.checks.commitEvents(appState) as! [DeletionsInsertionsEvent]
    let periodicDailyEvents = PeriodicChecklistDailyEvent(
      storageEvents: storageEvents,
      checksEvents: checkEvents)
    return [periodicDailyEvents]
  }
}
