//
//  CRDTTextView.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 8/27/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//

import Foundation
import UIKit

class CRDTTextView: UITextView {
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

