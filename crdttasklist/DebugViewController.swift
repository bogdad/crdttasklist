//
//  DebugViewController.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-03-15.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import UIKit

class DebugViewController: UIViewController {

    @IBAction func eraseDataClicked(_ sender: Any) {
        NoteStorage.shared.eraseAllData()
    }

    @IBAction func proceedClicked(_ sender: Any) {
        NoteStorage.shared.debugShown = true
        let navigationController = self.storyboard?.instantiateViewController(withIdentifier: "NavigationController")
        self.present(navigationController!, animated: true, completion: nil)
    }

}
