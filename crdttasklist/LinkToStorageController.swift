//
//  LinkToStorageViewController.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-01-27.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import UIKit
import SwiftyDropbox

class LinkToStorageViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Design.applyToUIView(view)
        // Check if the user is logged in
        // If so, display photo view controller
        NotificationCenter.default.addObserver(self, selector: #selector(onDropboxAvailable), name: NSNotification.Name("DropboxLogin"), object: nil)
        onDropboxAvailable()
    }

    @objc func onDropboxAvailable() {
        if NoteStorage.shared.isStorageLinked() {
            let navigationController = self.storyboard?.instantiateViewController(withIdentifier: "NavigationController")

            NoteStorage.shared.loadNotes()
            DispatchQueue.main.async {
                self.present(navigationController!, animated: true, completion: nil)
            }
        }
    }

    @IBAction func linkToDropboxPressed(_ sender: Any) {
        DropboxClientsManager.authorizeFromController(UIApplication.shared, controller: self, openURL: {(url: URL) -> Void in UIApplication.shared.openURL(url)})
    }
}
