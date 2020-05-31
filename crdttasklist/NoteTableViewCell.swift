//
//  NoteTableViewCell.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 10/4/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//

import Foundation
import UIKit

class NoteTableViewCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func setIntensity(_ note: Note) {
        let int1 = note.intensity1()
        let int2 = note.intensity2()
        if int1 > 0 && int2 > 0 {
            backgroundColor = UIColor.systemRed.withAlphaComponent(CGFloat(int1 + int2))
        } else if int1 > 0 {
            backgroundColor = UIColor.systemPink.withAlphaComponent(CGFloat(int1))
        } else if int2 > 0 {
            backgroundColor = UIColor.systemOrange.withAlphaComponent(CGFloat(int2))
        } else {
            backgroundColor = Design.grayBackround()
        }
    }

}
