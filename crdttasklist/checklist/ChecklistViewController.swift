//
//  ChecklistViewController.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-23.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import UIKit

class ChecklistViewController: UIViewController {

  @IBOutlet weak var onSwitch: UISwitch!
  @IBOutlet weak var timePicker: UIDatePicker!
  @IBOutlet weak var notePreview: UITextView!
  @IBOutlet weak var complete: UISwitch!
  @IBOutlet weak var titleLab: UINavigationItem!
  @IBOutlet weak var bar: UINavigationBar!
  @IBOutlet weak var doneButton: UIBarButtonItem!

  var note: Note?

  var enabled: Bool = false

  var checklist: ChecklistCRDT?

  override func viewDidLoad() {
    super.viewDidLoad()

    Design.applyToUIView(self.view)
    Design.applyToUIView(bar)
    Design.applyToTextView(notePreview)

    note = NoteStorage.shared.currentNote!

    navigationItem.title = note?.getDisplayName()

    checklist = ChecklistCRDT()
    checklist?.newSession()

    let _ = checklist?.merge(note!.checklistCRDT!)

    print("checkist \(checklist?.to_string() ?? "??")")
    let daily = checklist!.getDaily() ?? (23, 59)
    timePicker.setDate(fromDailyToDate(daily), animated: true)
    notePreview.text = note!.crdt.to_string()
    titleLab.title = note?.getDisplayName()

    enabled = checklist!.isSetDaily()
    handleEnabled()
    handleComplete()
  }
  @IBAction func onChanged(_ sender: Any) {
    enabled = !enabled
    handleEnabled()
  }
  @IBAction func completeChanged(_ sender: Any) {
    if !checklist!.isCompletedDaily() {
      checklist!.completeDaily()
    } else {
      checklist!.uncompleteDaily()
    }
    handleComplete()
  }
  @IBAction func timePicked(_ sender: Any) {
    if enabled {
      let date = timePicker.date
      checklist?.setDaily(fromDateToDaily(date))
    }
  }

  func handleComplete() {
    complete.setOn(checklist!.isCompletedDaily(), animated: true)
  }

  func handleEnabled() {
    if enabled {
      if checklist?.getDaily() == nil {
        let daily = checklist!.getDaily() ?? (23, 59)
        timePicker.setDate(fromDailyToDate(daily), animated: true)
      }
      timePicker.isEnabled = true
      checklist?.setDaily(fromDateToDaily(timePicker.date))
      complete.isEnabled = true
      onSwitch.isOn = true
    } else {
      timePicker.isEnabled = false
      print("\(checklist?.to_string() ?? "??")")
      checklist?.clearDaily()
      checklist?.uncompleteDaily()
      print("\(checklist?.to_string() ?? "??")")
      complete.isEnabled = false
      onSwitch.isOn = false
    }
  }

  func fromDailyToDate(_ daily: (Int, Int)) -> Date {
    let calendar: Calendar = NSCalendar.current
    var components = calendar.dateComponents([.hour, .minute], from: Date())
    components.hour = daily.0
    components.minute = daily.1
    return calendar.date(from: components)!
  }

  func fromDateToDaily(_ date: Date) -> (Int, Int) {
    let calendar: Calendar = NSCalendar.current
    let components = calendar.dateComponents([.hour, .minute], from: date)
    return (components.hour!, components.minute!)
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    super.prepare(for: segue, sender: sender)
    guard let button = sender as? UIBarButtonItem, button === doneButton else {
      return
    }
    print("checklist \(checklist?.to_string() ?? "??")")
    NoteStorage.shared.editingFinished(checklist!)
  }
}
