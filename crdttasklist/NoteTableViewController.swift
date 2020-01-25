//
//  NoteTableViewController.swift
//  crdttasklist
//
//  Created by Vladimir on 2019-11-25.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//

import UIKit

class NoteTableViewController: UITableViewController {

    var notes = [Note]()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem

        loadSampleNotes()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let idetifier = "NoteTableViewCell"

        guard let cell = tableView.dequeueReusableCell(withIdentifier: idetifier, for: indexPath) as? NoteTableViewCell else {
            fatalError("The dequeued cell is not an instance of NoteTableViewCell.")
        }

        let note = notes[indexPath.row]
        cell.nameLabel.text = note.text

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
       tableView.deselectRow(at: indexPath, animated: true)
       let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
       if let dataPresentingViewController = storyBoard.instantiateViewController(withIdentifier: "NoteViewController") as? NoteViewController {
           self.present(dataPresentingViewController, animated: true, completion: nil)
           dataPresentingViewController.nameLabel.text = notes[indexPath.row].name
           dataPresentingViewController.textView.text = notes[indexPath.row].text
       }
    }

    private func loadSampleNotes() {
        let note1 = Note("1", "some note 1")
        let note2 = Note("2", "some note 2")
        notes += [note1, note2]
    }
}
