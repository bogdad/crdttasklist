//
//  NoteNavigationController.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-30.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import UIKit

class NoteNavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()

        Design.applyToNavigationController(self)
    }

}
