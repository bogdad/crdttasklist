//
//  NoteTableViewController.swift
//  crdttasklist
//
//  Created by Vladimir on 2019-11-25.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//

import UIKit
import SwiftyDropbox

enum CellEditType {
    case add
    case update
    case delete
    case undelete
}

class NoteTableViewController: UITableViewController {

    var remoteTimer: Timer?
    var debugShown = false
    var editedNoteIndex: Int?
    @IBOutlet weak var filterButton: UIBarButtonItem!
    var filter: NoteTableFilter = .active

    override func viewDidLoad() {
        super.viewDidLoad()

        Design.applyToUIView(view)
        Design.applyToTableView(tableView)

        if !NoteStorage.shared.isStorageLinked() {
            let linkToSorageViewController = self.storyboard?.instantiateViewController(withIdentifier: "LinkToStorageViewController")
            present(linkToSorageViewController!, animated: true, completion: nil)
        } else {
            NoteStorage.shared.loadNotes({_ in
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            })
            navigationItem.leftBarButtonItem = editButtonItem

            NotificationCenter.default.addObserver(self, selector: #selector(notesChangedRemotely), name: NSNotification.Name("notesChangedRemotely"), object: nil)
            remoteTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(runTimedCode), userInfo: nil, repeats: true)
        }

        filterButton.title = "Active"
        filter = .active
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?){
        if motion == .motionShake {
            performSegue(withIdentifier: "debugShake", sender: self)
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return getNotes().count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let idetifier = "NoteTableViewCell"

        guard let cell = tableView.dequeueReusableCell(withIdentifier: idetifier, for: indexPath) as? NoteTableViewCell else {
            fatalError("The dequeued cell is not an instance of NoteTableViewCell.")
        }

        let note = noteByIndex(indexPath.row)
        Design.applyToLabel(cell.nameLabel!, note.getDisplayName())
        cell.setIntensity(note)

        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            var note = noteByIndex(indexPath.row)
            editedNoteIndex = indexPath.row
            noteUpdate(&note, .delete)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
            var note = Note.newNote()
            NoteStorage.shared.append(&note)
        }
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { (_, _, completionHandler) in
            self.editedNoteIndex = indexPath.row
            var note = self.noteByIndex(indexPath.row)
            self.noteUpdate(&note, .delete)
            completionHandler(true)
        }
        let swipeConfig = UISwipeActionsConfiguration(actions: [deleteAction])
        return swipeConfig
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        var note = noteByIndex(indexPath.row)
        let setChecklistAction = UIContextualAction(style: .normal, title: "Checklist") { (action, sourceView, completionHandler) in
            let cell = tableView.cellForRow(at: indexPath)
            self.performSegue(withIdentifier: "checklistSegue", sender: cell)
            completionHandler(true)
        }
        var actions = [setChecklistAction]
        if filter == .all && (note.isActive() == false) {
            let undeleteAction = UIContextualAction(style: .normal, title: "Undelete") { (action, sourceView, completionHandler) in
                self.editedNoteIndex = indexPath.row
                self.noteUpdate(&note, .undelete)
                completionHandler(true)
            }
            actions.append(undeleteAction)
        }
        let swipeConfig = UISwipeActionsConfiguration(actions: actions)
        return swipeConfig
    }

    func noteForSender(_ sender: Any?) -> Note {
        guard let selectedNoteCell = sender as? NoteTableViewCell else {
            fatalError("Unexpected sender: \(sender ?? "???")")
        }
        guard let indexPath = tableView.indexPath(for: selectedNoteCell) else {
            fatalError("The selected cell is not being displayed by the table")
        }
        return getNotes()[indexPath.row]
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        switch(segue.identifier ?? "") {
        case "AddItem":
            NoteStorage.shared.currentNote = nil
            editedNoteIndex = nil
            break
        case "ShowDetail":
            let selectedNote = noteForSender(sender)
            editedNoteIndex = indexNote(selectedNote)
            NoteStorage.shared.currentNote = selectedNote
        case "checklistSegue":
            let selectedNote = noteForSender(sender)
            editedNoteIndex = indexNote(selectedNote)
            NoteStorage.shared.currentNote = selectedNote
        case "debugShake":
            break
        default:
            fatalError("Unexpected Segue Identifier; \(segue.identifier ?? "???")")
        }
    }


    @IBAction func unwindToNoteList(sender: UIStoryboardSegue) {
        if sender.identifier == "unwindNote" {
            if var note = NoteStorage.shared.currentNote {
                if let oldIndex = tableView.indexPathForSelectedRow {
                    // Update an existing note.
                    editedNoteIndex = oldIndex.row
                    noteUpdate(&note, .update)
                }
                else {
                    // Add a new note.w
                    noteUpdate(&NoteStorage.shared.currentNote!, .add)
                }
            }
        } else if sender.identifier == "unwindChecklist" {
            if var note = NoteStorage.shared.currentNote {
                noteUpdate(&note, .update)
            }
        }
    }

    @IBAction func startEditing(_ sender: UIBarButtonItem) {
        if (!isEditing) {
            isEditing = true
        } else {
            isEditing = false
        }
    }

    func noteUpdate(_ note: inout Note, _ type: CellEditType) {
        var oldIndex: Int? = editedNoteIndex
        var newIndex: Int? = nil
        switch type {
        case .add:
            NoteStorage.shared.append(&note)
            newIndex = indexNote(note)
        case .update:
            NoteStorage.shared.update(&note)
            newIndex = indexNote(note)
        case .delete:
            NoteStorage.shared.markDeleted(note)
        case .undelete:
            NoteStorage.shared.markUndeleted(note)
        }
        if let newIndex = newIndex {
            let newCell = cellByIndex(newIndex)
            newCell.setIntensity(note)
        }
        if let oldIndex = oldIndex {
            let oldNote = noteByIndex(oldIndex)
            let oldCell = cellByIndex(oldIndex)
            oldCell.setIntensity(oldNote)
        }
        switch type {
        case .add:
            tableView.insertRows(at: [IndexPath(item: newIndex!, section: 0)], with: .automatic)
        case .update:
            tableView.reloadRows(at: indexPaths(oldIndex!, newIndex!), with: .none)
        case .delete:
            tableView.deleteRows(at: [IndexPath(item: oldIndex!, section: 0)], with: .fade)
        case .undelete:
            tableView.reloadRows(at: [IndexPath(item: oldIndex!, section: 0)], with: .none)
        }
    }

    func indexPaths(_ i: Int...) -> [IndexPath] {
        return i.map { IndexPath(item: $0, section: 0)}
    }

    func indexNote(_ note: Note) -> Int {
        return getNotes().firstIndex(where: {$0.id! == note.id!})!
    }

    func cellByIndex(_ i: Int) -> NoteTableViewCell {
        let indexPath =  IndexPath(item: i, section: 0)
        return tableView.cellForRow(at: indexPath)! as! NoteTableViewCell
    }

    func cellByNote(_ note: Note) -> NoteTableViewCell {
        let index = indexNote(note)
        let indexPath =  IndexPath(item: index, section: 0)
        return tableView.cellForRow(at: indexPath)! as! NoteTableViewCell
    }

    func noteByIndex(_ i: Int) -> Note {
        return getNotes()[i]
    }

    private func getNotes() -> [Note] {
        return NoteStorage.shared.notes(filter)
    }

    @objc func notesChangedRemotely() {
        guard let updated = NoteRemoteStorage.shared.popLatest() else {
            return
        }
        NoteStorage.shared._notes = updated
        self.tableView.reloadData()
    }

    @objc func runTimedCode() {
        DispatchQueue.main.async {
            //NoteStorage.shared.checkRemotes()
        }
    }
    @IBAction func filterClicked(_ sender: Any) {
        if filter == .active {
            filter = .all
        } else {
            filter = .active
        }
        handleFilter()
    }

    func handleFilter() {
        if filter == .active {
            filterButton.title = "Active"
        } else {
            filterButton.title = "All"
        }
        tableView.reloadData()
    }

}
