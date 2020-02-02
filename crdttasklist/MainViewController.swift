//
//  MainViewController.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-01-27.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import UIKit
import SwiftyDropbox

class MainViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Check if the user is logged in
        // If so, display photo view controller
        NotificationCenter.default.addObserver(self, selector: #selector(onDropboxAvailable), name: NSNotification.Name("DropboxLogin"), object: nil)
        onDropboxAvailable()
    }

    @objc func onDropboxAvailable() {
        if let client = DropboxClientsManager.authorizedClient {
            //let navigationController = self.storyboard?.instantiateViewController(withIdentifier: "NavigationController")
            let noteTableViewController = self.storyboard?.instantiateViewController(withIdentifier: "NoteTableViewController")

            NoteStorage.shared.loadNotes(client)
            DispatchQueue.main.async {
                self.present(noteTableViewController!, animated: true, completion: nil)
            }
        }
    }

    @IBAction func linkToDropboxPressed(_ sender: Any) {
        DropboxClientsManager.authorizeFromController(UIApplication.shared, controller: self, openURL: {(url: URL) -> Void in UIApplication.shared.openURL(url)})
    }
}
