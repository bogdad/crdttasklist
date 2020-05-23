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

    @IBOutlet weak var enabledButton: UIButton!
    @IBOutlet var navBar: UIView!
    @IBOutlet weak var tomePicker: UIDatePicker!
    @IBOutlet weak var notePreview: UITextView!
    @IBOutlet weak var nb: UINavigationBar!
    @IBOutlet weak var ttl: UINavigationItem!
    var note: Note?

    var enabled: Bool = false

    var checklist: ChecklistCRDT?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = note?.getDisplayName()

        checklist = note!.checklistCRDT!
        checklist?.newSession()

        let daily = checklist!.getDaily() ?? (23, 59)
        tomePicker.setDate(fromDailyToDate(daily), animated: true)
        notePreview.text = note!.crdt.to_string()
        ttl.title = note!.crdt.to_string()

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
            enabledButton.titleLabel?.text = "Enabled"
        } else {
            Design.applyToSelectedCheckbox(enabledButton)
            tomePicker.isEnabled = false
            checklist?.clear()
            enabledButton.titleLabel?.text = "Not a checklist"
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
        let components = calendar.dateComponents([.hour, .minute], from: Date())
        return (components.hour!, components.minute!)
    }
}
