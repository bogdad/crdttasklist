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
        attributes[.kern] = 0.7
        label.font = UIFont.systemFont(ofSize: 22, weight: .light)
        label.attributedText = NSAttributedString(string: string, attributes: attributes)
    }

    static func applyToTextView(_ textView: UITextView) {
        let font = UIFont.systemFont(ofSize: 22, weight: .light)
        var attributes:[NSAttributedString.Key: Any] = [:]
        attributes[.kern] = 0.7
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 8
        attributes[.paragraphStyle] = style
        attributes[.font] = font
        if #available(iOS 13.0, *) {
            attributes[.foregroundColor] = UIColor.label
            attributes[.backgroundColor] = grayBackround()
        } else {
            // Fallback on earlier versions
        }
        textView.font = font
        textView.typingAttributes = attributes
        textView.attributedText = NSAttributedString(string: textView.text, attributes: attributes)

        if #available(iOS 13.0, *) {
            textView.backgroundColor = grayBackround()
        } else {
            // Fallback on earlier versions
        }
    }

    static func applyToUIView(_ view: UIView) {
        if #available(iOS 13.0, *) {
            view.backgroundColor = grayBackround()
        } else {
            // Fallback on earlier versions
        }
    }

    static func applyToTableView(_ t: UITableView) {
        if #available(iOS 13.0, *) {
            t.backgroundColor = grayBackround()
        } else {
            // Fallback on earlier versions
        }
    }

    static func applyToNavigationController(_ navController: UINavigationController) {
        applyToUIView(navController.view)
        if #available(iOS 13.0, *) {
            navController.navigationBar.barTintColor = grayBackround()
        } else {
            // Fallback on earlier versions
        }
    }

    static func grayBackround() -> UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.systemGray5
        } else {
            return UIColor.gray
        }
    }
}
