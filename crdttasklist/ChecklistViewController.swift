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

    @IBOutlet weak var titleLabel: UINavigationItem!
    @IBOutlet weak var enabledButton: UIButton!
    @IBOutlet weak var tomePicker: UIDatePicker!
    @IBOutlet weak var notePreview: UITextView!

    var note: Note?

    var enabled: Bool = false

    var checklist: ChecklistCRDT?

    override func viewDidLoad() {
        super.viewDidLoad()

        note = NoteStorage.shared.currentNote!

        navigationItem.title = note?.getDisplayName()

        checklist = ChecklistCRDT()
        checklist?.newSession()

        checklist?.merge(note!.checklistCRDT!)

        print("checkist \(checklist?.to_string() ?? "??")")
        let daily = checklist!.getDaily() ?? (23, 59)
        tomePicker.setDate(fromDailyToDate(daily), animated: true)
        notePreview.text = note!.crdt.to_string()

        enabled = checklist!.isSet()
        handleEnabled()
    }
    @IBAction func timePicked(_ sender: Any) {
        if enabled {
            let date = tomePicker.date
            checklist?.setDaily(fromDateToDaily(date))
        }
    }
    @IBAction func checkedCliecked(_ sender: Any) {
        enabled = !enabled
        handleEnabled()
    }

    func handleEnabled() {
        if enabled {
            if checklist?.getDaily() == nil {
                let daily = checklist!.getDaily() ?? (23, 59)
                tomePicker.setDate(fromDailyToDate(daily), animated: true)
            }
            tomePicker.isEnabled = true
            checklist?.setDaily(fromDateToDaily(tomePicker.date))
            Design.applyToSelectedCheckbox(enabledButton)
            enabledButton.setTitle("Daily check: enabled", for: .normal)
        } else {
            Design.applyToSelectedCheckbox(enabledButton)
            tomePicker.isEnabled = false
            print("\(checklist?.to_string() ?? "??")")
            checklist?.clear()
            print("\(checklist?.to_string() ?? "??")")
            enabledButton.setTitle("Daily check: nah", for: .normal)
        }
    }

    func fromDailyToDate(_ daily: (Int, Int)) -> Date {
        let calendar:Calendar = NSCalendar.current
        var components = calendar.dateComponents([.hour, .minute], from: Date())
        components.hour = daily.0
        components.minute = daily.1
        return calendar.date(from: components)!
    }

    func fromDateToDaily(_ date: Date) -> (Int, Int) {
        let calendar:Calendar = NSCalendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour!, components.minute!)
    }
    @IBAction func done(_ sender: Any) {

    }
    @IBOutlet weak var doneButton: UIBarButtonItem!

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        guard let button = sender as? UIBarButtonItem, button === doneButton else {
            return
        }
        print("checklist \(checklist?.to_string() ?? "??")")
        NoteStorage.shared.editingFinished(checklist!)
    }
}
