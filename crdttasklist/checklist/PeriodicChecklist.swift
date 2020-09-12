//
//  PeriodicChecklist.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-06-19.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

protocol PeriodicChecklist {
  associatedtype Item

  mutating func intensity() -> Double
  func start(_ curDate: Date) -> Date
  func end(_ curDate: Date) -> Date
  func isSet() -> Bool
  func isCompleted() -> Bool

  func get() -> Item?

  mutating func complete()
  mutating func uncomplete()
  mutating func set(_ item: Item)
  mutating func clear()

  func maybeFromString() -> Item?
  func fromString() -> Item
  func toString(_ item: Item) -> String

  func modificationDate() -> Date
  mutating func newSession()
  mutating func editing_finished()
}
