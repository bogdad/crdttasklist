//
//  NoteViewController.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-01-25.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import UIKit

class NoteViewController: UIViewController {

    @IBOutlet weak var nameText: UITextField!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    var note: Note?

    override func viewDidLoad() {
        super.viewDidLoad()
        if let note = note {
            navigationItem.title = note.name
            nameText.text = note.name
            textView.text = note.text
        } else {
            nameText.text = "name?"
            textView.text = "text?"
        }
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
        let name = nameText.text ?? ""
        let text = textView.text ?? ""
        note = Note(name, text)
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
