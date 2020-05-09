//
//  NoteTableViewController.swift
//  crdttasklist
//
//  Created by Vladimir on 2019-11-25.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//

import UIKit
import SwiftyDropbox

class NoteTableViewController: UITableViewController {

    var remoteTimer: Timer?
    var debugShown = false

    override func viewDidLoad() {
        super.viewDidLoad()

        if !NoteStorage.shared.isStorageLinked() {
            let linkToSorageViewController = self.storyboard?.instantiateViewController(withIdentifier: "LinkToStorageViewController")
            present(linkToSorageViewController!, animated: true, completion: nil)
        } else {
            NoteStorage.shared.loadNotes()
            navigationItem.leftBarButtonItem = editButtonItem

            NotificationCenter.default.addObserver(self, selector: #selector(notesChangedRemotely), name: NSNotification.Name("notesChangedRemotely"), object: nil)
            remoteTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(runTimedCode), userInfo: nil, repeats: true)
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return NoteStorage.shared.getNotes().count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let idetifier = "NoteTableViewCell"

        guard let cell = tableView.dequeueReusableCell(withIdentifier: idetifier, for: indexPath) as? NoteTableViewCell else {
            fatalError("The dequeued cell is not an instance of NoteTableViewCell.")
        }

        let note = getNotes()[indexPath.row]
        cell.nameLabel!.text = String(note.getDisplayName())

        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            NoteStorage.shared.markDeleted(indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
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

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        switch(segue.identifier ?? "") {
        case "AddItem":
            NoteStorage.shared.currentNote = nil
            break
        case "ShowDetail":
            guard let noteViewController = segue.destination as? CRDTNoteViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            guard let selectedNoteCell = sender as? NoteTableViewCell else {
                fatalError("Unexpected sender: \(sender)")
            }
            guard let indexPath = tableView.indexPath(for: selectedNoteCell) else {
                fatalError("The selected cell is not being displayed by the table")
            }
            let selectedNote = getNotes()[indexPath.row]
            NoteStorage.shared.currentNote = selectedNote
        default:
            fatalError("Unexpected Segue Identifier; \(segue.identifier)")
        }
    }


    @IBAction func unwindToNoteList(sender: UIStoryboardSegue) {
        if var note = NoteStorage.shared.currentNote {
            if let selectedIndexPath = tableView.indexPathForSelectedRow {
                // Update an existing meal.
                NoteStorage.shared.update(&note)
                tableView.reloadRows(at: [selectedIndexPath, IndexPath.init(row: 0, section: 0)], with: .none)
            }
            else {
                // Add a new note.
                let newIndexPath = IndexPath(row: getNotes().count, section: 0)
                NoteStorage.shared.append(&NoteStorage.shared.currentNote!)
                tableView.insertRows(at: [newIndexPath], with: .automatic)
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


    private func getNotes() -> [Note] {
        return NoteStorage.shared.getNotes()
    }

    @objc func notesChangedRemotely() {
        self.tableView.reloadData()
    }

    @objc func runTimedCode() {
        DispatchQueue.main.async {
            //NoteStorage.shared.checkRemotes()
        }
    }
}
