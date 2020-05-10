//
//  Design.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-09.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import UIKit

struct Design {

    static func applyToLabel(_ label: UILabel, _ string: String) {
        var attributes:[NSAttributedString.Key: Any] = [:]
        attributes[.kern] = 0.6
        label.font = UIFont.systemFont(ofSize: 22, weight: .regular)
        label.attributedText = NSAttributedString(string: string, attributes: attributes)
    }

    static func applyToTextView(_ textView: UITextView) {
        let font = UIFont.systemFont(ofSize: 22, weight: .regular)
        var attributes:[NSAttributedString.Key: Any] = [:]
        attributes[.kern] = 0.6
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 8
        attributes[.paragraphStyle] = style
        attributes[.font] = font
        textView.font = font
        textView.typingAttributes = attributes
        textView.alpha = 0.9
        textView.attributedText = NSAttributedString(string: textView.text, attributes: attributes)
    }
}
