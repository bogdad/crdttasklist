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

  var daily: PeriodicChecklistDaily?
  var weekly: PeriodicChecklistWeekly?

  var intensityWeeklyCache: Double?

  init() {
    daily = PeriodicChecklistDaily()
    weekly = PeriodicChecklistWeekly()
  }

  mutating func merge(_ other: ChecklistCRDT) -> (CRDTMergeResult, Self) {
    var res = CRDTMergeResult(selfChanged: false, otherChanged: false)
    let (dr, nd) = daily!.merge(other.daily!)
    self.daily = nd
    res.merge(dr)
    let (wr, nw) = weekly!.merge(other.weekly!)
    self.weekly = nw
    res.merge(wr)
    intensityWeeklyCache = nil
    return (res, self)
  }

  mutating func tryMigrate() -> Bool {
  var res = false
    if var daily = daily {
      if daily.tryMigrate() {
        self.daily = daily
        res = true
      }
    } else {
      daily = PeriodicChecklistDaily()
      res = true
    }
    if var weekly = weekly {
      if weekly.tryMigrate() {
        self.weekly = weekly
        res = true
      }
    } else {
      weekly = PeriodicChecklistWeekly()
      res = true
    }
    return res
  }

  func modificationDate() -> Date {
    return Swift.max(
      weekly!.modificationDate(), daily!.modificationDate())
  }

  func to_string() -> String {
    return "\(daily!.to_string()) \(daily!.to_string())"
  }

  mutating func newSession() {
    daily!.newSession()
    weekly!.newSession()
  }

  mutating func editing_finished() {
    daily!.editing_finished()
    weekly!.editing_finished()
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

  mutating func clearWeekly() {
    weekly!.clear()
  }

  func getWeekly() -> Int? {
    return weekly!.get()
  }

  func isSetWeekly() -> Bool {
    return weekly!.isSet()
  }

  func isCompletedWeekly() -> Bool {
    return weekly!.isCompleted()
  }

  mutating func completeWeekly() {
    weekly!.complete()
  }

  mutating func uncompleteWeekly() {
    weekly!.uncomplete()
  }

  mutating func setWeekly(_ weekday: Int) {
    weekly!.set(weekday)
  }
}

extension ChecklistCRDT: Storable {
  mutating func commitEvents(_ appState: AppState) -> [Event] {
    let dailyEvents = self.daily!.commitEvents(appState) as! [PeriodicChecklistDailyEvent]
    let weeklyEvents = self.weekly!.commitEvents(appState) as! [PeriodicChecklistWeeklyEvent]
    let checklistCRDTEvent = ChecklistCRDTEvent(
      dailyEvents: dailyEvents, weeklyEvents: weeklyEvents)
    return [checklistCRDTEvent]
  }
}
