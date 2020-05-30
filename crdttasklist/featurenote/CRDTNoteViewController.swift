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

        Design.applyToUIView(view)

        if let note = NoteStorage.shared.currentNote {
            navigationItem.title = note.getDisplayName()
            //textView!.text = note.text_snapshot()
            createTextView(note)
        } else {
            createTextView(nil)
        }
        registerForKeyboard()
    }

    func createTextView(_ note: Note?) {
        // 1
        //let attrs = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body)]
        //let attrString = NSAttributedString(string: note?.crdt.to_string() ?? "", attributes: attrs)
        if note != nil {
            note!.crdt.new_session()
        }
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
        Design.applyToUIView(textView)
        textView.allowsEditingTextAttributes = false
        Design.applyToTextView(textView)
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

        textView.isScrollEnabled = true
        textView.scrollRangeToVisible(NSMakeRange(0, 0))
        textView.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
        if #available(iOS 13.0, *) {
            textView.textColor = UIColor.label
        } else {
            // Fallback on earlier versions
        }

        self.textView = textView
        self.textView?.becomeFirstResponder()
    }

    @objc func keyboardWasShown(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo else {
            return
        }
        let rect = userInfo[UIResponder.keyboardFrameEndUserInfoKey]! as! CGRect
        let kbSize = rect.size
        let contentInsets = UIEdgeInsets(top: 0, left: 0.0, bottom: kbSize.height, right: 0.0)
        self.textView!.contentInset = contentInsets
    }

    @objc func keyboardWasHidden(_ notification: NSNotification) {
        let contentInsets = UIEdgeInsets.zero
        self.textView!.contentInset = contentInsets
    }

    func registerForKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWasShown),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWasHidden(_:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
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
        NoteStorage.shared.editingFinished(textStorage!.crdt)
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
