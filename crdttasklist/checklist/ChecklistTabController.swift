//
//  CheclistTabController.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-31.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import UIKit

class ChecklistTabController: UITabBarController {

    var note: Note?

    override func viewDidLoad() {
        super.viewDidLoad()

        note = NoteStorage.shared.currentNote!

        if (note!.checklistCRDT!.isSetDaily()) {
            selectedIndex = 0
        } else if (note!.checklistCRDT!.isSetWeekly()) {
            selectedIndex = 1
        }
    }
}
