//
//  ChecklistWeeklyViewController.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-31.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import UIKit

class ChecklistWeeklyViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var onSwitch: UISwitch!
    @IBOutlet weak var completeSwitch: UISwitch!
    @IBOutlet weak var bar: UINavigationBar!
    @IBOutlet weak var notePreview: UITextView!
    @IBOutlet weak var weekDaySelect: UITableView!
    @IBOutlet weak var titleLab: UINavigationItem!

    var note: Note?
    var checklist: ChecklistCRDT?
    var enabled: Bool = false

    var days: [String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    var isWeekend: [Bool] = [false, false, false, false, false, true, true]

    var selectedDay: Int = 6

    override func viewDidLoad() {
        super.viewDidLoad()

        Design.applyToUIView(self.view)
        Design.applyToUIView(bar)
        Design.applyToTextView(notePreview)

        note = NoteStorage.shared.currentNote!

        navigationItem.title = note?.getDisplayName()

        checklist = ChecklistCRDT()
        checklist?.newSession()

        setupTableView()
        checklist?.merge(note!.checklistCRDT!)

        print("checkist \(checklist?.to_string() ?? "??")")

        let weekly = checklist?.getWeekly() ?? 6
        tbsetDay(weekly)

        notePreview.text = note!.crdt.to_string()
        titleLab.title = note?.getDisplayName()

        enabled = checklist!.isSetWeekly()
        handleEnabled()
        handleComplete()
    }

    func setupTableView() {
        weekDaySelect.delegate = self
        weekDaySelect.dataSource = self
    }

    @IBAction func completeChanged(_ sender: Any) {
        if !checklist!.isCompletedWeekly() {
            checklist!.completeWeekly()
        } else {
            checklist!.uncompleteWeekly()
        }
        handleComplete()
    }
    @IBAction func onChanged(_ sender: Any) {
        enabled = !enabled
        handleEnabled()
    }
    func handleComplete() {
        completeSwitch.setOn(checklist!.isCompletedWeekly(), animated: true)
    }

    func handleEnabled() {
        if enabled {
            if checklist?.getWeekly() == nil {
                let daily = checklist!.getWeekly() ?? 6
                tbsetDay(daily)
            }
            checklist?.setWeekly(selectedDay)
            completeSwitch.isEnabled = true
            onSwitch.isOn = true
        } else {
            print("\(checklist?.to_string() ?? "??")")
            checklist?.clearWeekly()
            checklist?.uncompleteWeekly()
            print("\(checklist?.to_string() ?? "??")")
            completeSwitch.isEnabled = false
            onSwitch.isOn = false
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 7
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let idetifier = "dayOfWeekCell"

        guard let cell = tableView.dequeueReusableCell(withIdentifier: idetifier, for: indexPath) as? ChecklistWeeklyTableViewCell else {
            fatalError("The dequeued cell is not an instance of NoteTableViewCell.")
        }

        let day = days[indexPath.row]

        cell.label.text = day
        if isWeekend[indexPath.row] {
            cell.label.textColor = UIColor.systemRed
        }

        return cell
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    private func tbsetDay(_ weekday: Int) {
        weekDaySelect.selectRow(at: IndexPath(item: weekday, section: 0), animated: true, scrollPosition: UITableView.ScrollPosition.top)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedDay = indexPath.row
        if enabled {
            checklist?.setWeekly(selectedDay)
        }
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
