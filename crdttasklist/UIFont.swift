//
//  UIFont.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-05-09.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import UIKit

extension UIFont {

    enum Font: String {
        case SFUIText = "SFUIText"
        case SFUIDisplay = "SFUIDisplay"
    }

    private static func name(of weight: UIFont.Weight) -> String? {
        switch weight {
            case .ultraLight: return "UltraLight"
            case .thin: return "Thin"
            case .light: return "Light"
            case .regular: return nil
            case .medium: return "Medium"
            case .semibold: return "Semibold"
            case .bold: return "Bold"
            case .heavy: return "Heavy"
            case .black: return "Black"
            default: return nil
        }
    }

    convenience init?(font: Font, weight: UIFont.Weight, size: CGFloat) {
        var fontName = ".\(font.rawValue)"
        if let weightName = UIFont.name(of: weight) { fontName += "-\(weightName)" }
        self.init(name: fontName, size: size)
    }
}
