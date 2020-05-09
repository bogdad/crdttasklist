//
//  NoteViewCRDTViewController.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-02-02.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation


import UIKit

class CRDTNoteViewController: UIViewController, UITextViewDelegate, NSTextStorageDelegate {

    var textView: CRDTTextView?
    var textStorage: CRDTTextStorage?

    @IBOutlet weak var saveButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        if let note = NoteStorage.shared.currentNote {
            navigationItem.title = note.getDisplayName()
            //textView!.text = note.text_snapshot()
            createTextView(note)
        } else {
            createTextView(nil)
        }
    }

    func createTextView(_ note: Note?) {
        // 1
        //let attrs = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body)]
        //let attrString = NSAttributedString(string: note?.crdt.to_string() ?? "", attributes: attrs)
        textStorage = CRDTTextStorage(note?.crdt)
        //textStorage!.append(NSAttributedString(string: ""))
        //textStorage!.append(attrString)

        let newTextViewRect = view.bounds

        // 2
        let layoutManager = NSLayoutManager()

        // 3
        let containerSize = CGSize(width: newTextViewRect.width,
                                 height: .greatestFiniteMagnitude)
        let container = NSTextContainer(size: containerSize)
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)
        textStorage!.addLayoutManager(layoutManager)

        // 4
        let textView: CRDTTextView = CRDTTextView(frame: newTextViewRect, textContainer: container)
        textView.delegate = self
        view.addSubview(textView)

        // 5
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
        textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        textView.topAnchor.constraint(equalTo: view.topAnchor),
        textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        textView.font = UIFont.systemFont(ofSize: 25)

        self.textView = textView
    }

    @IBAction func dismissPressed(_ sender:Any) {
       let isPresentingInAddMealMode = presentingViewController is UINavigationController
       if isPresentingInAddMealMode {
           dismiss(animated: true, completion: nil)
       } else if let owningNavigationController = navigationController{
           owningNavigationController.popViewController(animated: true)
       }
    }

    //MARK: Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        guard let button = sender as? UIBarButtonItem, button === saveButton else {
            return
        }
        textStorage?.crdt { NoteStorage.shared.editingFinished($0) }
    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        // Depending on style of presentation (modal or push presentation), this view controller needs to be dismissed in two different ways.
        let isPresentingInAddMealMode = presentingViewController is UINavigationController
        if isPresentingInAddMealMode {
            dismiss(animated: true, completion: nil)
        }
        else if let owningNavigationController = navigationController{
            owningNavigationController.popViewController(animated: true)
        } else {
            fatalError("The MealViewController is not inside a navigation controller.")
        }
    }
}
